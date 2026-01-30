#!/bin/bash

# Logging functions
log_info() {
    local message="[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

log_success() {
    local message="[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

log_warning() {
    local message="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message" >&2
    echo "$message" >> "$LOG_FILE"
}

log_error() {
    local message="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message" >&2
    echo "$message" >> "$LOG_FILE"
}

log_skip() {
    local message="[SKIP] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# State management functions
get_last_sha() {
    local repo_path=$1
    jq -r --arg repo "$repo_path" \
        '.repositories[$repo].last_bundle_sha // "none"' "$STATE_FILE"
}

get_last_bundle_date() {
    local repo_path=$1
    jq -r --arg repo "$repo_path" \
        '.repositories[$repo].last_bundle_date // "never"' "$STATE_FILE"
}

get_last_bundle_type() {
    local repo_path=$1
    jq -r --arg repo "$repo_path" \
        '.repositories[$repo].bundle_type // "none"' "$STATE_FILE"
}

update_state() {
    local repo_path=$1
    local sha=$2
    local bundle_type=$3
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    jq --arg repo "$repo_path" \
       --arg sha "$sha" \
       --arg date "$timestamp" \
       --arg type "$bundle_type" \
       '.repositories[$repo] = {
           "last_bundle_sha": $sha,
           "last_bundle_date": $date,
           "bundle_type": $type
       }' "$STATE_FILE" > "${STATE_FILE}.tmp"
    
    if [ $? -eq 0 ]; then
        mv "${STATE_FILE}.tmp" "$STATE_FILE"
        return 0
    else
        log_error "Failed to update state file"
        rm -f "${STATE_FILE}.tmp"
        return 1
    fi
}

get_current_sha() {
    local local_repo=$1
    local default_branch=$(git -C "$local_repo" symbolic-ref --short HEAD 2>/dev/null || echo "main")
    git -C "$local_repo" rev-parse "$default_branch" 2>/dev/null
}

clone_or_update_repo() {
    local project_path=$1
    local local_repo="$REPOS_DIR/$project_path"
    
    mkdir -p "$(dirname "$local_repo")"
    
    if [ ! -d "$local_repo" ]; then
        log_info "Cloning $project_path for the first time..."
        git clone --mirror "$GITLAB_SSH:$project_path.git" "$local_repo" 2>&1 | tee -a "$LOG_FILE"
        local clone_status=$?
        
        # Set HEAD to main after cloning
        if [ $clone_status -eq 0 ]; then
            git -C "$local_repo" symbolic-ref HEAD refs/heads/main 2>&1 | tee -a "$LOG_FILE"
        fi
        
        return $clone_status
    else
        if [ "$VERBOSE" = true ]; then
            log_info "Updating $project_path..."
        fi
        git -C "$local_repo" remote update --prune 2>&1 | tee -a "$LOG_FILE"
        local update_status=$?
        
        # Make sure HEAD points to main
        if [ $update_status -eq 0 ]; then
            git -C "$local_repo" symbolic-ref HEAD refs/heads/main 2>/dev/null
        fi
        
        return $update_status
    fi
}

verify_bundle() {
    local bundle_file=$1
    
    log_info "Verifying bundle: $(basename "$bundle_file")"
    
    # Find any git repo to use for verification
    local verify_repo=""
    
    # Try to find an existing repo
    for repo_path in "${REPOS[@]}"; do
        local test_repo="$REPOS_DIR/$repo_path"
        if [ -d "$test_repo" ]; then
            verify_repo="$test_repo"
            break
        fi
    done
    
    # If no repo found, create a temporary one
    if [ -z "$verify_repo" ]; then
        verify_repo="/tmp/bundle_verify_$$"
        mkdir -p "$verify_repo"
        git -C "$verify_repo" init --bare >> "$LOG_FILE" 2>&1
    fi
    
    # Run verification from within the git repo
    local verify_output=$(git -C "$verify_repo" bundle verify "$bundle_file" 2>&1)
    local verify_status=$?
    
    # Clean up temp repo if we created one
    if [[ "$verify_repo" == /tmp/bundle_verify_* ]]; then
        rm -rf "$verify_repo"
    fi
    
    # Log the output
    echo "$verify_output" >> "$LOG_FILE"
    
    if [ $verify_status -eq 0 ]; then
        log_info "Bundle verification successful"
        return 0
    else
        log_error "Bundle verification failed: $verify_output"
        return 1
    fi
}

create_bundle() {
    local local_repo=$1
    local bundle_file=$2
    local last_sha=$3
    local bundle_type=$4
    
    mkdir -p "$(dirname "$bundle_file")"
    
    # Get the actual default branch (main or master)
    local default_branch=$(git -C "$local_repo" symbolic-ref --short HEAD 2>/dev/null || echo "main")
    
    if [ "$bundle_type" == "full" ]; then
        log_info "Creating full bundle with --all..."
        git -C "$local_repo" bundle create "$bundle_file" --all 2>&1 | tee -a "$LOG_FILE"
        return $?
    else
        # For incremental, verify the range exists first
        log_info "Verifying commit range $last_sha..$default_branch..."
        
        # Check if last_sha exists in the repository
        if ! git -C "$local_repo" cat-file -e "$last_sha" 2>/dev/null; then
            log_warning "Last SHA $last_sha not found in repository, creating full bundle instead..."
            git -C "$local_repo" bundle create "$bundle_file" --all 2>&1 | tee -a "$LOG_FILE"
            return $?
        fi
        
        # Check if there are actually commits in the range
        local commit_count=$(git -C "$local_repo" rev-list --count "$last_sha..$default_branch" 2>/dev/null)
        
        if [ -z "$commit_count" ] || [ "$commit_count" -eq 0 ]; then
            log_warning "No commits in range $last_sha..$default_branch, bundle may be empty"
        fi
        
        log_info "Creating incremental bundle for $commit_count commit(s) on branch $default_branch..."
        git -C "$local_repo" bundle create "$bundle_file" "$last_sha..$default_branch" 2>&1 | tee -a "$LOG_FILE"
        return $?
    fi
}

create_metadata() {
    local bundle_file=$1
    local repo_path=$2
    local from_sha=$3
    local to_sha=$4
    local bundle_type=$5
    
    local file_size=$(stat -f%z "$bundle_file" 2>/dev/null || stat -c%s "$bundle_file")
    
    cat > "${bundle_file}.meta" <<EOF
{
    "repository": "$repo_path",
    "from_sha": "$from_sha",
    "to_sha": "$to_sha",
    "bundle_type": "$bundle_type",
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "file_size": $file_size,
    "bundle_file": "$(basename "$bundle_file")"
}
EOF
}

# File size formatting
format_size() {
    local size=$1
    if [ $size -lt 1024 ]; then
        echo "${size}B"
    elif [ $size -lt 1048576 ]; then
        echo "$(( size / 1024 ))KB"
    else
        echo "$(( size / 1048576 ))MB"
    fi
}

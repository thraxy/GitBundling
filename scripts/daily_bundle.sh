#!/bin/bash

# Load configuration and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/bundle_config.sh"
source "$SCRIPT_DIR/bundle_utils.sh"

# Set output directory for today
BUNDLE_OUTPUT_DIR="$INCREMENTAL_BUNDLE_DIR/$(date +%Y%m%d)"
mkdir -p "$BUNDLE_OUTPUT_DIR"

echo "========================================="
echo "Daily Incremental Bundle Sync"
echo "========================================="
log_info "Starting daily incremental bundle process"
log_info "Output directory: $BUNDLE_OUTPUT_DIR"
echo ""

# Track statistics
total_repos=0
bundled_repos=0
skipped_repos=0
failed_repos=0

for project_path in "${REPOS[@]}"; do
    ((total_repos++))
    
    echo "----------------------------------------"
    echo "Repository: $project_path"
    echo "----------------------------------------"
    
    # Clone or update repository
    if ! clone_or_update_repo "$project_path"; then
        log_error "Failed to clone/update $project_path"
        ((failed_repos++))
        echo ""
        continue
    fi
    
    # Get current SHA
    local_repo="$REPOS_DIR/$project_path"
    current_sha=$(get_current_sha "$local_repo")
    
    if [ -z "$current_sha" ]; then
        log_error "Could not get current SHA for $project_path"
        ((failed_repos++))
        echo ""
        continue
    fi
    
    log_info "Current HEAD SHA: $current_sha"
    
    # Get last bundled SHA
    last_sha=$(get_last_sha "$project_path")
    last_date=$(get_last_bundle_date "$project_path")
    
    log_info "Last bundled SHA: $last_sha"
    log_info "Last bundle date: $last_date"
    
    # Check for changes
    if [ "$current_sha" == "$last_sha" ]; then
        log_skip "No changes detected - skipping bundle creation"
        ((skipped_repos++))
        echo ""
        continue
    fi
    
    # # DEBUG: Force bundle creation
    # echo "DEBUG: Current SHA = $current_sha"
    # echo "DEBUG: Last SHA = $last_sha"
    # echo "DEBUG: Forcing bundle creation for testing..."

    log_info "Changes detected - creating bundle..."
    
    # Determine bundle type
    if [ "$last_sha" == "none" ]; then
        bundle_type="full"
        log_info "First time bundling - creating full bundle"
    else
        bundle_type="incremental"
        log_info "Creating incremental bundle ($last_sha..HEAD)"
    fi
    
    # Create bundle
    bundle_file="$BUNDLE_OUTPUT_DIR/${project_path//\//_}.bundle"
    
    if create_bundle "$local_repo" "$bundle_file" "$last_sha" "$bundle_type"; then
        # Verify bundle
        if verify_bundle "$bundle_file"; then
            file_size=$(stat -f%z "$bundle_file" 2>/dev/null || stat -c%s "$bundle_file")
            formatted_size=$(format_size $file_size)
            
            log_success "Bundle created successfully: $(basename "$bundle_file")"
            log_info "Bundle size: $formatted_size"
            
            # Create metadata
            create_metadata "$bundle_file" "$project_path" "$last_sha" "$current_sha" "$bundle_type"
            log_info "Metadata saved: $(basename "$bundle_file").meta"
            
            # Update state
            if update_state "$project_path" "$current_sha" "$bundle_type"; then
                log_success "State updated for $project_path"
                ((bundled_repos++))
            else
                log_error "Failed to update state for $project_path"
                ((failed_repos++))
            fi
        else
            log_error "Bundle verification failed"
            rm -f "$bundle_file"
            ((failed_repos++))
        fi
    else
        log_error "Bundle creation failed"
        ((failed_repos++))
    fi
    
    echo ""
done

echo "========================================="
echo "Daily Bundle Sync Complete"
echo "========================================="
log_info "Summary: Total=$total_repos, Bundled=$bundled_repos, Skipped=$skipped_repos, Failed=$failed_repos"
log_info "Bundles location: $BUNDLE_OUTPUT_DIR"
log_info "State file: $STATE_FILE"
echo ""

# Display summary table
echo "Repository Summary:"
echo "-------------------"
for project_path in "${REPOS[@]}"; do
    last_sha=$(get_last_sha "$project_path")
    last_date=$(get_last_bundle_date "$project_path")
    last_type=$(get_last_bundle_type "$project_path")
    echo "$project_path:"
    echo "  SHA: $last_sha"
    echo "  Date: $last_date"
    echo "  Type: $last_type"
done

exit 0

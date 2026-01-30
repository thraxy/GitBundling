#!/bin/bash

# Configuration for target server
BUNDLE_DIR="$1"
TARGET_GITLAB_SSH="git@gitlab.target.com"
LOG_FILE="apply_bundles_$(date +%Y%m%d_%H%M%S).log"

if [ -z "$BUNDLE_DIR" ]; then
    echo "Usage: $0 <bundle_directory>"
    exit 1
fi

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Error: Directory $BUNDLE_DIR does not exist"
    exit 1
fi

echo "========================================="
echo "Applying Git Bundles"
echo "========================================="
echo "Bundle directory: $BUNDLE_DIR"
echo "Target GitLab: $TARGET_GITLAB_SSH"
echo "Log file: $LOG_FILE"
echo ""

bundles_applied=0
bundles_failed=0

for bundle in "$BUNDLE_DIR"/*.bundle; do
    if [ ! -f "$bundle" ]; then
        continue
    fi
    
    meta_file="${bundle}.meta"
    
    echo "----------------------------------------"
    echo "Processing: $(basename "$bundle")"
    echo "----------------------------------------"
    
    # Check for metadata
    if [ ! -f "$meta_file" ]; then
        echo "[WARNING] No metadata file found, skipping" | tee -a "$LOG_FILE"
        ((bundles_failed++))
        echo ""
        continue
    fi
    
    # Read metadata
    repo_path=$(jq -r '.repository' "$meta_file")
    bundle_type=$(jq -r '.bundle_type' "$meta_file")
    from_sha=$(jq -r '.from_sha' "$meta_file")
    to_sha=$(jq -r '.to_sha' "$meta_file")
    
    echo "[INFO] Repository: $repo_path" | tee -a "$LOG_FILE"
    echo "[INFO] Bundle type: $bundle_type" | tee -a "$LOG_FILE"
    echo "[INFO] From SHA: $from_sha" | tee -a "$LOG_FILE"
    echo "[INFO] To SHA: $to_sha" | tee -a "$LOG_FILE"
    
    # Verify bundle
    echo "[INFO] Verifying bundle..." | tee -a "$LOG_FILE"
    if ! git bundle verify "$bundle" >> "$LOG_FILE" 2>&1; then
        echo "[ERROR] Bundle verification failed" | tee -a "$LOG_FILE"
        ((bundles_failed++))
        echo ""
        continue
    fi
    echo "[SUCCESS] Bundle verified" | tee -a "$LOG_FILE"
    
    # Setup local repository
    local_repo="./temp_repos/$repo_path"
    mkdir -p "$(dirname "$local_repo")"
    
    if [ ! -d "$local_repo" ]; then
        echo "[INFO] Cloning from bundle..." | tee -a "$LOG_FILE"
        git clone --mirror "$bundle" "$local_repo" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            cd "$local_repo"
            git remote set-url origin "$TARGET_GITLAB_SSH:$repo_path.git"
            cd - > /dev/null
        else
            echo "[ERROR] Failed to clone from bundle" | tee -a "$LOG_FILE"
            ((bundles_failed++))
            echo ""
            continue
        fi
    else
        echo "[INFO] Fetching from bundle..." | tee -a "$LOG_FILE"
        cd "$local_repo"
        git fetch "$bundle" >> "$LOG_FILE" 2>&1
        
        if [ $? -ne 0 ]; then
            echo "[ERROR] Failed to fetch from bundle" | tee -a "$LOG_FILE"
            cd - > /dev/null
            ((bundles_failed++))
            echo ""
            continue
        fi
        cd - > /dev/null
    fi
    
    # Push to target GitLab
    echo "[INFO] Pushing to target GitLab..." | tee -a "$LOG_FILE"
    cd "$local_repo"
    git push --mirror "$TARGET_GITLAB_SSH:$repo_path.git" >> "$LOG_FILE" 2>&1
    push_status=$?
    cd - > /dev/null
    
    if [ $push_status -eq 0 ]; then
        echo "[SUCCESS] Successfully synced $repo_path" | tee -a "$LOG_FILE"
        ((bundles_applied++))
    else
        echo "[ERROR] Failed to push to target GitLab" | tee -a "$LOG_FILE"
        ((bundles_failed++))
    fi
    
    echo ""
done

echo "========================================="
echo "Bundle Application Complete"
echo "========================================="
echo "Applied: $bundles_applied"
echo "Failed: $bundles_failed"
echo "Log file: $LOG_FILE"

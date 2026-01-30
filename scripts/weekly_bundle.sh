#!/bin/bash

# Load configuration and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/bundle_config.sh"
source "$SCRIPT_DIR/bundle_utils.sh"

# Set output directory for this week
BUNDLE_OUTPUT_DIR="$FULL_BUNDLE_DIR/$(date +%Y%m%d)"
mkdir -p "$BUNDLE_OUTPUT_DIR"

echo "========================================="
echo "Weekly Full Bundle Sync"
echo "========================================="
log_info "Starting weekly full bundle process"
log_info "Output directory: $BUNDLE_OUTPUT_DIR"
echo ""

# Track statistics
total_repos=0
bundled_repos=0
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
    log_info "Creating full bundle..."
    
    # Create full bundle
    bundle_file="$BUNDLE_OUTPUT_DIR/${project_path//\//_}.bundle"
    
    if create_bundle "$local_repo" "$bundle_file" "" "full"; then
        # Verify bundle
        if verify_bundle "$bundle_file"; then
            file_size=$(stat -f%z "$bundle_file" 2>/dev/null || stat -c%s "$bundle_file")
            formatted_size=$(format_size $file_size)
            
            log_success "Full bundle created successfully: $(basename "$bundle_file")"
            log_info "Bundle size: $formatted_size"
            
            # Create metadata
            create_metadata "$bundle_file" "$project_path" "none" "$current_sha" "full"
            log_info "Metadata saved: $(basename "$bundle_file").meta"
            
            # Update state
            if update_state "$project_path" "$current_sha" "full"; then
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
echo "Weekly Full Bundle Sync Complete"
echo "========================================="
log_info "Summary: Total=$total_repos, Bundled=$bundled_repos, Failed=$failed_repos"
log_info "Bundles location: $BUNDLE_OUTPUT_DIR"
log_info "State file: $STATE_FILE"
echo ""

exit 0

#!/bin/bash

# GitLab Configuration
export GITLAB_SSH="git@gitlab.com"
export GITLAB_NAMESPACE="nthrax"

# Repositories to sync
export REPOS=(
    "nthrax/testing-diffs"
    "nthrax/testing-diffs-2"
)

# Directories
export BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export STATE_FILE="$BASE_DIR/bundle_state.json"
export REPOS_DIR="$BASE_DIR/repos"
export BUNDLES_BASE_DIR="$BASE_DIR/bundles"
export LOG_DIR="$BASE_DIR/logs"

# Bundle settings
export INCREMENTAL_BUNDLE_DIR="$BUNDLES_BASE_DIR/incremental"
export FULL_BUNDLE_DIR="$BUNDLES_BASE_DIR/full"

# Logging
export LOG_FILE="$LOG_DIR/bundle_sync_$(date +%Y%m%d).log"
export VERBOSE=true

# Create necessary directories
mkdir -p "$REPOS_DIR"
mkdir -p "$INCREMENTAL_BUNDLE_DIR"
mkdir -p "$FULL_BUNDLE_DIR"
mkdir -p "$LOG_DIR"

# Initialize state file if needed
if [ ! -f "$STATE_FILE" ]; then
    echo '{"repositories":{}}' > "$STATE_FILE"
fi

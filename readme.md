# Git Bundle Sync System

A bash-based system for syncing GitLab repositories between air-gapped servers using git bundles. This system creates efficient incremental bundles for daily syncs and complete snapshots for weekly backups.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [File Structure](#file-structure)
- [How It Works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Automation](#automation)
- [FAQ](#faq)

## Overview

This system solves the problem of syncing Git repositories between two GitLab servers that cannot have a direct network connection (air-gapped environments). It uses git bundles to package repository changes and tracks state to enable efficient incremental updates.

### What are Git Bundles?

Git bundles are portable archives of Git repositories that can be transferred via USB drives, shared folders, or any other physical media. They contain all the commits, branches, and tags needed to reconstruct a repository.

## Features

- **Differential Detection**: Only bundles repositories that have changed since last sync
- **Incremental Bundles**: Daily sync creates small bundles with only new commits
- **Full Snapshots**: Weekly sync creates complete repository backups
- **State Tracking**: Maintains SHA history to detect changes
- **Automatic Verification**: Validates all bundles before considering them successful
- **Comprehensive Logging**: All operations logged with timestamps
- **Metadata Files**: Each bundle includes JSON metadata for traceability
- **Windows/Git Bash Compatible**: Works on Windows, Linux, and macOS

## Prerequisites

### Required Software

- **Git**: Version 2.0 or higher
- **jq**: JSON processor for state management
- **SSH**: For GitLab authentication
- **Bash**: Version 4.0 or higher

### Installation of Dependencies

#### Windows (Git Bash)
```bash
# Install jq
winget install jqlang.jq

# Git Bash comes with Git and SSH
```

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install git jq ssh
```

#### macOS
```bash
brew install git jq
```

## Installation

### 1. Clone or Download This Repository
```bash
mkdir ~/git-bundle-sync
cd ~/git-bundle-sync
# Copy all script files here
```

### 2. Configure SSH Keys for GitLab
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Start SSH agent
eval "$(ssh-agent -s)"

# Add key
ssh-add ~/.ssh/id_ed25519

# Display public key
cat ~/.ssh/id_ed25519.pub
```

### 3. Add SSH Key to GitLab

1. Copy your public key from the previous step
2. Go to GitLab: **Settings → SSH Keys**
3. Paste your public key
4. Click **Add key**

### 4. Test GitLab Connection
```bash
ssh -T git@gitlab.com
# Should see: "Welcome to GitLab, @yourusername!"
```

### 5. Run Setup Script
```bash
chmod +x setup.sh
./setup.sh
```

This will:
- Make all scripts executable
- Check for required dependencies
- Verify GitLab SSH connection
- Create necessary directories

## Configuration

### Edit `bundle_config.sh`

Update the following settings:
```bash
# GitLab Configuration
export GITLAB_SSH="git@gitlab.com"  # Your GitLab server
export GITLAB_NAMESPACE="your-username"

# Repositories to sync
export REPOS=(
    "namespace/repo1"
    "namespace/repo2"
    "namespace/repo3"
)
```

### Configuration Options

| Variable | Description | Example |
|----------|-------------|---------|
| `GITLAB_SSH` | GitLab SSH URL | `git@gitlab.com` |
| `GITLAB_NAMESPACE` | Your GitLab username/group | `nthrax` |
| `REPOS` | Array of repositories to sync | `("user/repo1" "user/repo2")` |
| `BASE_DIR` | Base directory for all files | Auto-detected |
| `VERBOSE` | Show detailed output | `true` or `false` |

## Usage

### Daily Incremental Sync

Run this daily to bundle only changed repositories:
```bash
./daily_bundle.sh
```

**Output:**
- Creates bundles in: `bundles/incremental/YYYYMMDD/`
- Updates `bundle_state.json` with new SHAs
- Logs to: `logs/bundle_sync_YYYYMMDD.log`

**Behavior:**
- Compares current repo SHA with last bundled SHA
- If unchanged: skips the repository
- If changed: creates incremental bundle with only new commits
- If first time: creates full bundle

### Weekly Full Sync

Run this weekly to create complete snapshots:
```bash
./weekly_bundle.sh
```

**Output:**
- Creates bundles in: `bundles/full/YYYYMMDD/`
- Always creates complete bundles regardless of changes
- Updates state file

### Applying Bundles on Target Server

On your air-gapped target server:
```bash
# Copy bundle files to target server (USB drive, etc.)
# Then run:
./apply_bundles.sh /path/to/received_bundles
```

This will:
1. Verify each bundle
2. Extract and merge changes
3. Push to target GitLab server

### Diagnostics

If something isn't working:
```bash
./diagnose.sh
```

This comprehensive diagnostic checks:
- All dependencies
- SSH connections
- Directory structure
- State file contents
- Recent logs
- Actual bundle creation test

## File Structure
```
git-bundle-sync/
├── bundle_config.sh          # Configuration settings
├── bundle_utils.sh           # Reusable helper functions
├── daily_bundle.sh           # Daily incremental sync script
├── weekly_bundle.sh          # Weekly full sync script
├── apply_bundles.sh          # Target server application script
├── setup.sh                  # Initial setup and validation
├── diagnose.sh               # Troubleshooting diagnostics
├── bundle_state.json         # SHA tracking (auto-created)
├── repos/                    # Local mirror repositories
│   └── namespace/
│       ├── repo1/
│       └── repo2/
├── bundles/                  # Created bundles
│   ├── incremental/
│   │   └── 20260129/
│   │       ├── namespace_repo1.bundle
│   │       └── namespace_repo1.bundle.meta
│   └── full/
│       └── 20260129/
│           ├── namespace_repo1.bundle
│           └── namespace_repo1.bundle.meta
└── logs/                     # Log files
    └── bundle_sync_20260129.log
```

### Key Files Explained

#### `bundle_state.json`
Tracks the last bundled commit SHA for each repository:
```json
{
  "repositories": {
    "namespace/repo1": {
      "last_bundle_sha": "abc123...",
      "last_bundle_date": "2026-01-29T23:45:00Z",
      "bundle_type": "incremental"
    }
  }
}
```

#### Bundle Metadata Files (`.meta`)
Each bundle has an accompanying metadata file:
```json
{
  "repository": "namespace/repo1",
  "from_sha": "abc123...",
  "to_sha": "def456...",
  "bundle_type": "incremental",
  "created_at": "2026-01-29T23:45:00Z",
  "file_size": 1024
}
```

## How It Works

### Daily Incremental Workflow

1. **Clone/Update Local Mirrors**
   - First run: `git clone --mirror` creates local repository copies
   - Subsequent runs: `git remote update` fetches latest changes

2. **SHA Comparison**
   - Gets current HEAD SHA: `git rev-parse main`
   - Reads last bundled SHA from `bundle_state.json`
   - Compares: if equal → skip, if different → bundle

3. **Bundle Creation**
   - **First time**: `git bundle create bundle.bundle --all`
   - **Incremental**: `git bundle create bundle.bundle last_sha..HEAD`

4. **Verification**
   - Runs `git bundle verify` from within a git repository context
   - Ensures bundle is valid and not corrupted

5. **State Update**
   - Saves new SHA to `bundle_state.json`
   - Next run will use this SHA for comparison

### Example Scenario

**Day 1 - First Run:**
```
Repo1: last_sha=none, current_sha=abc123
Action: Create FULL bundle (all commits)
State: Save abc123

Repo2: last_sha=none, current_sha=def456
Action: Create FULL bundle (all commits)
State: Save def456
```

**Day 2 - No Changes:**
```
Repo1: last_sha=abc123, current_sha=abc123
Action: SKIP (no changes)

Repo2: last_sha=def456, current_sha=def456
Action: SKIP (no changes)
```

**Day 3 - One Repo Changed:**
```
Repo1: last_sha=abc123, current_sha=xyz789
Action: Create INCREMENTAL bundle (abc123..xyz789)
State: Save xyz789

Repo2: last_sha=def456, current_sha=def456
Action: SKIP (no changes)
```

## Troubleshooting

### Common Issues

#### "jq is not installed"

**Solution:**
```bash
# Windows
winget install jqlang.jq

# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Then restart your terminal
```

#### "Bundle verification failed"

**Cause:** Git needs to be inside a repository to verify bundles.

**Solution:** Already fixed in `bundle_utils.sh` - the `verify_bundle()` function runs verification from within a git repository context.

**Manual verification:**
```bash
cd repos/namespace/repo1/
git bundle verify ../../bundles/incremental/20260129/namespace_repo1.bundle
```

#### "No bundles created"

**Check:**
```bash
# 1. Are repos being cloned?
ls -la repos/

# 2. What does the state file say?
cat bundle_state.json | jq .

# 3. Check logs
cat logs/bundle_sync_$(date +%Y%m%d).log

# 4. Run diagnostics
./diagnose.sh
```

**Common causes:**
- State file SHAs match current SHAs (no changes detected)
- SSH authentication issues
- Permission problems

#### "SSH connection failed"

**Solution:**
```bash
# Test connection
ssh -T git@gitlab.com

# If fails, check SSH key
ls -la ~/.ssh/

# Re-add key to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

#### Bundles created but can't be applied on target

**Check:**
1. Bundle verification: `git bundle verify bundle.bundle` (from within a repo)
2. Bundle metadata exists: `ls -la *.meta`
3. Target GitLab is accessible via SSH
4. Repository exists on target GitLab

### Reset Everything

If you want to start fresh:
```bash
# Backup current state
cp bundle_state.json bundle_state.json.backup

# Delete local mirrors
rm -rf repos/

# Reset state file
echo '{"repositories":{}}' > bundle_state.json

# Next run will create fresh full bundles
./daily_bundle.sh
```

### Force Bundle Creation (Testing)

To force bundle creation regardless of changes:
```bash
# Reset state file
echo '{"repositories":{}}' > bundle_state.json

# Run daily sync (will treat all as first-time)
./daily_bundle.sh
```

## Automation

### Cron Setup (Linux/macOS)
```bash
# Edit crontab
crontab -e

# Add these lines:

# Daily incremental bundles at 2 AM
0 2 * * * /path/to/daily_bundle.sh >> /var/log/git-bundle-daily.log 2>&1

# Weekly full bundles on Sunday at 3 AM
0 3 * * 0 /path/to/weekly_bundle.sh >> /var/log/git-bundle-weekly.log 2>&1
```

### Task Scheduler (Windows)

1. Open **Task Scheduler**
2. Create new task
3. **Trigger:** Daily at 2:00 AM
4. **Action:** Run `C:\Program Files\Git\bin\bash.exe`
5. **Arguments:** `-c "/c/path/to/daily_bundle.sh"`
6. Repeat for weekly bundle

### Post-Bundle Transfer Script

After creating bundles, you might want to automatically copy them:
```bash
#!/bin/bash
# transfer_bundles.sh

SOURCE_DIR="/path/to/bundles/incremental/$(date +%Y%m%d)"
DEST_DIR="/mnt/usb/bundles/"

if [ -d "$SOURCE_DIR" ]; then
    rsync -av "$SOURCE_DIR" "$DEST_DIR"
    echo "Bundles transferred to $DEST_DIR"
else
    echo "No bundles found for today"
fi
```

## FAQ

### Q: How much disk space do I need?

**A:** It depends on your repository sizes:
- **Local mirrors**: Same size as your repositories
- **Incremental bundles**: Usually small (only new commits)
- **Full bundles**: Same size as repository
- **Recommendation**: 3x total repository size

### Q: Can I add more repositories later?

**A:** Yes! Just edit `bundle_config.sh`:
```bash
export REPOS=(
    "namespace/existing-repo1"
    "namespace/existing-repo2"
    "namespace/new-repo3"  # Add this
)
```

Next run will automatically clone and bundle the new repo.

### Q: What if a repository is deleted from GitLab?

**A:** The script will fail to clone/update that repo and log an error. You should remove it from the `REPOS` array in `bundle_config.sh`.

### Q: Can I run daily and weekly bundles on the same day?

**A:** Yes, they're independent. Daily creates incremental bundles, weekly creates full bundles. They're stored in different directories.

### Q: How do incremental bundles work if I miss days?

**A:** Incremental bundles use the last bundled SHA from `bundle_state.json`. If you miss days, the next incremental bundle will include all commits since the last bundle, not just since yesterday.

Example:
- Monday: Bundle created, SHA saved
- Tuesday-Thursday: Missed (script didn't run)
- Friday: Bundle includes all commits from Monday to Friday

### Q: What happens if `bundle_state.json` is corrupted or lost?

**A:** The script will treat all repositories as new and create full bundles. You can restore from a backup or let it rebuild naturally.

### Q: Can I bundle private repositories?

**A:** Yes, as long as your SSH key has access. The bundle inherits the same permissions as your git clone.

### Q: How do I sync to multiple target servers?

**A:** Copy the bundles to each target server and run `apply_bundles.sh` on each one independently.

### Q: Do bundles include Git LFS files?

**A:** Git bundles do NOT include LFS files by default. You'll need to handle LFS files separately if your repositories use them.

### Q: Can I exclude certain branches from bundles?

**A:** The current implementation bundles all branches (`--all` flag). To customize, modify the `create_bundle()` function in `bundle_utils.sh`:
```bash
# Only bundle main branch
git bundle create "$bundle_file" main
```

### Q: What's the maximum bundle size?

**A:** No hard limit, but for practical reasons:
- Keep bundles under 2GB for easy transfer
- If larger, consider splitting by repository or using weekly full bundles less frequently

## Advanced Usage

### Custom Bundle Filters

Edit `bundle_config.sh` to add repository filtering:
```bash
# Only bundle repos matching a pattern
export REPO_FILTER="project-*"

# Only bundle from specific namespaces
export NAMESPACE_FILTER="team1,team2"
```

### Notification Integration

Add to the end of `daily_bundle.sh`:
```bash
# Send email notification
if [ $failed_repos -gt 0 ]; then
    echo "Bundle sync completed with $failed_repos failures" | mail -s "Bundle Sync Alert" admin@example.com
fi
```

### Cleanup Old Bundles

Add a cleanup script:
```bash
#!/bin/bash
# cleanup_old_bundles.sh

# Keep only last 7 days of incremental bundles
find bundles/incremental/ -type d -mtime +7 -exec rm -rf {} \;

# Keep only last 4 weeks of full bundles
find bundles/full/ -type d -mtime +28 -exec rm -rf {} \;
```

## Support

For issues, questions, or contributions:
1. Check the troubleshooting section
2. Run `./diagnose.sh` for diagnostics
3. Check log files in `logs/`
4. Review the state file: `cat bundle_state.json | jq .`

## License

This project is provided as-is for use in air-gapped GitLab synchronization scenarios.

## Credits

Developed to solve the challenge of syncing GitLab repositories between air-gapped servers using git's native bundle functionality combined with intelligent differential detection.

---

**Version:** 1.0  
**Last Updated:** January 2026
#!/bin/bash

echo "Git Bundle Sync - Setup"
echo "======================="
echo ""

# Make scripts executable
chmod +x bundle_config.sh
chmod +x bundle_utils.sh
chmod +x daily_bundle.sh
chmod +x weekly_bundle.sh
chmod +x apply_bundles.sh

echo "[SUCCESS] Scripts made executable"

# Check dependencies
echo ""
echo "Checking dependencies..."

command -v git >/dev/null 2>&1 || { echo "[ERROR] git is not installed"; exit 1; }
echo "[OK] git found"

command -v jq >/dev/null 2>&1 || { echo "[ERROR] jq is not installed"; exit 1; }
echo "[OK] jq found"

command -v ssh >/dev/null 2>&1 || { echo "[ERROR] ssh is not installed"; exit 1; }
echo "[OK] ssh found"

# Test GitLab SSH connection
echo ""
echo "Testing GitLab SSH connection..."
ssh -T git@gitlab.com 2>&1 | grep -q "Welcome"

if [ $? -eq 0 ]; then
    echo "[SUCCESS] GitLab SSH connection working"
else
    echo "[WARNING] GitLab SSH connection may not be configured"
    echo "Please run: ssh-keygen -t ed25519 -C 'your_email@example.com'"
    echo "Then add your public key to GitLab at: https://gitlab.com/-/profile/keys"
fi

echo ""
echo "Setup complete!"
echo ""
echo "To run daily sync: ./daily_bundle.sh"
echo "To run weekly sync: ./weekly_bundle.sh"

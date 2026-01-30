#!/bin/bash

echo "========================================="
echo "COMPLETE DIAGNOSTIC"
echo "========================================="
echo ""

echo "1. Checking environment..."
echo "   Current directory: $(pwd)"
echo "   User: $(whoami)"
echo ""

echo "2. Checking dependencies..."
command -v git && echo "   [OK] git found" || echo "   [ERROR] git not found"
command -v jq && echo "   [OK] jq found" || echo "   [ERROR] jq not found"
command -v ssh && echo "   [OK] ssh found" || echo "   [ERROR] ssh not found"
echo ""

echo "3. Testing jq..."
echo '{"test":"value"}' | jq . && echo "   [OK] jq works" || echo "   [ERROR] jq doesn't work"
echo ""

echo "4. Testing GitLab SSH..."
ssh -T git@gitlab.com 2>&1 | head -3
echo ""

echo "5. Checking directories..."
ls -la | grep -E "bundle_config|bundle_utils|daily_bundle"
echo ""

echo "6. Checking if config loads..."
if [ -f "./bundle_config.sh" ]; then
    echo "   bundle_config.sh exists"
    source ./bundle_config.sh 2>&1
    if [ $? -eq 0 ]; then
        echo "   [OK] Config loaded"
        echo "   GITLAB_SSH: $GITLAB_SSH"
        echo "   STATE_FILE: $STATE_FILE"
        echo "   REPOS_DIR: $REPOS_DIR"
        echo "   REPOS array has ${#REPOS[@]} items"
    else
        echo "   [ERROR] Config failed to load"
    fi
else
    echo "   [ERROR] bundle_config.sh not found"
fi
echo ""

echo "7. Checking if utilities load..."
if [ -f "./bundle_utils.sh" ]; then
    echo "   bundle_utils.sh exists"
    source ./bundle_utils.sh 2>&1
    if [ $? -eq 0 ]; then
        echo "   [OK] Utilities loaded"
        # Test a function
        type get_current_sha > /dev/null 2>&1 && echo "   [OK] Functions available" || echo "   [ERROR] Functions not available"
    else
        echo "   [ERROR] Utilities failed to load"
    fi
else
    echo "   [ERROR] bundle_utils.sh not found"
fi
echo ""

echo "8. Checking directory structure..."
echo "   repos/: $(ls -d repos 2>/dev/null && echo 'exists' || echo 'does not exist')"
echo "   bundles/: $(ls -d bundles 2>/dev/null && echo 'exists' || echo 'does not exist')"
echo "   logs/: $(ls -d logs 2>/dev/null && echo 'exists' || echo 'does not exist')"
echo ""

echo "9. Checking repos directory contents..."
if [ -d "repos" ]; then
    ls -la repos/
    if [ -d "repos/nthrax" ]; then
        echo ""
        echo "   Checking nthrax repos..."
        ls -la repos/nthrax/
    fi
else
    echo "   No repos directory"
fi
echo ""

echo "10. Checking state file..."
if [ -f "bundle_state.json" ]; then
    echo "   bundle_state.json exists:"
    cat bundle_state.json
else
    echo "   bundle_state.json does not exist"
fi
echo ""

echo "11. Testing basic git clone..."
TEST_REPO="./test_clone_$$"
echo "   Attempting to clone to: $TEST_REPO"
git clone --mirror git@gitlab.com:nthrax/testing-diffs.git "$TEST_REPO" 2>&1 | head -10
if [ -d "$TEST_REPO" ]; then
    echo "   [OK] Clone successful"
    echo "   Repository info:"
    git -C "$TEST_REPO" log --oneline -3 2>&1
    echo "   Branches:"
    git -C "$TEST_REPO" branch -a 2>&1
    rm -rf "$TEST_REPO"
else
    echo "   [ERROR] Clone failed"
fi
echo ""

echo "12. Checking latest log file..."
if [ -d "logs" ]; then
    LATEST_LOG=$(ls -t logs/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "   Latest log: $LATEST_LOG"
        echo "   Last 20 lines:"
        tail -20 "$LATEST_LOG"
    else
        echo "   No log files found"
    fi
else
    echo "   No logs directory"
fi
echo ""

echo "========================================="
echo "DIAGNOSTIC COMPLETE"
echo "========================================="

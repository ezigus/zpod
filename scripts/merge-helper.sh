#!/bin/bash

# merge-helper.sh - Helper script for resolving dev-build.sh merge conflicts
# This script preserves the enhanced version of dev-build.sh during merges

set -euo pipefail

echo "🔄 Merge Conflict Resolution Helper for dev-build.sh"
echo "====================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_BUILD_PATH="$SCRIPT_DIR/dev-build.sh"
BACKUP_PATH="$SCRIPT_DIR/dev-build-enhanced.sh"

# Check if we have the enhanced version available
if [[ -f "$BACKUP_PATH" ]]; then
    echo "✅ Enhanced dev-build.sh backup found"
    
    # If there's a merge conflict, restore the enhanced version
    if git status --porcelain | grep -q "scripts/dev-build.sh"; then
        echo "🔧 Resolving merge conflict by restoring enhanced version..."
        cp "$BACKUP_PATH" "$DEV_BUILD_PATH"
        git add "$DEV_BUILD_PATH"
        echo "✅ Enhanced dev-build.sh restored and staged"
    else
        echo "ℹ️  No merge conflict detected for dev-build.sh"
    fi
else
    echo "❌ Enhanced backup not found at $BACKUP_PATH"
    exit 1
fi

echo ""
echo "Enhanced features preserved:"
echo "- Swift 6 concurrency pattern detection"
echo "- DispatchQueue anti-pattern warnings"
echo "- Non-exhaustive catch block detection"
echo "- @MainActor timer usage validation"
echo "- Comprehensive development testing"
echo ""
echo "✅ Merge conflict resolution complete!"
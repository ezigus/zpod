#!/bin/bash

# setup-merge-strategy.sh - Configure Git to preserve enhanced dev-build.sh during merges

echo "🔧 Setting up Git merge strategy for enhanced dev-build.sh"
echo "=========================================================="

# Configure Git to use the 'ours' strategy for dev-build.sh
git config merge.ours.driver true

# Add merge strategy to Git config for this repository
git config merge.enhanced-dev-script.driver './scripts/merge-helper.sh %O %A %B %L'
git config merge.enhanced-dev-script.name "Enhanced dev-build.sh merge driver"

echo "✅ Git merge strategy configured"
echo ""
echo "The following merge strategies are now active:"
echo "- scripts/dev-build.sh will use the enhanced version from this branch"
echo "- .gitattributes defines merge=ours for the script"
echo "- merge-helper.sh provides automatic conflict resolution"
echo ""
echo "During merges, the enhanced Swift 6 concurrency features will be preserved."
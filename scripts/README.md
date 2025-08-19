# Development Scripts

This directory contains development tools for the zPod project.

## Files

### `dev-build.sh` - Enhanced Development Build Script

The primary development script with Swift 6 concurrency support.

**Features:**
- Swift syntax validation for all source files
- Swift 6 concurrency pattern detection
- DispatchQueue anti-pattern warnings
- @MainActor timer usage validation
- Cross-platform development support

**Usage:**
```bash
# Run all checks (recommended)
./scripts/dev-build.sh all

# Check Swift 6 concurrency patterns
./scripts/dev-build.sh concurrency

# Run development tests
./scripts/dev-build.sh test

# Show help
./scripts/dev-build.sh help
```

### `dev-build-enhanced.sh` - Backup Copy

Enhanced version backup for merge conflict resolution.

### `merge-helper.sh` - Merge Conflict Resolver

Automatically resolves merge conflicts for `dev-build.sh` by preserving the enhanced version.

**Usage during merge conflicts:**
```bash
./scripts/merge-helper.sh
```

## Merge Conflict Resolution Process

If you encounter a merge conflict with `scripts/dev-build.sh`:

1. **Automatic Resolution:**
   ```bash
   ./scripts/merge-helper.sh
   git commit -m "Resolve merge conflict: preserve enhanced dev-build.sh"
   ```

2. **Manual Resolution:**
   - The enhanced version is backed up in `dev-build-enhanced.sh`
   - Copy the enhanced version over the conflicted file
   - The `.gitattributes` file is configured to prefer this branch's version

3. **Verification:**
   ```bash
   ./scripts/dev-build.sh test
   ```

## Enhanced Features in This Branch

The `dev-build.sh` script in this branch includes significant enhancements over the main branch:

- **Swift 6 Concurrency Detection**: Identifies common concurrency anti-patterns
- **DispatchQueue Analysis**: Warns about legacy patterns that should use Task-based concurrency
- **Error Handling Validation**: Detects non-exhaustive catch blocks
- **Actor Isolation Checks**: Validates @MainActor timer usage patterns
- **Early Warning System**: Catches potential compilation issues before CI/CD

These enhancements are critical for Swift 6 development and should be preserved during merges.

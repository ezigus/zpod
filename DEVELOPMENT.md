# Development Environment Guide

## xcodebuild Access and Development Tools

This document explains how to access xcodebuild functionality during development and provides alternative tools for different environments.

### macOS Development (Full xcodebuild Access)

If you're on macOS with Xcode installed:

```bash
# Check Xcode version
xcodebuild -version

# List available schemes and targets
xcodebuild -list -project zpod.xcodeproj

# Build the project
xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator

# Run tests
xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.2' test

# Clean build
xcodebuild -project zpod.xcodeproj -scheme zpod clean
```

### Non-macOS Development (Alternative Tools)

For development environments without Xcode (Linux, Windows, etc.), use the provided development script:

```bash
# Check project information and Swift syntax
./scripts/dev-build.sh all

# Run syntax checking only
./scripts/dev-build.sh syntax

# Show project information
./scripts/dev-build.sh info

# Show available targets and schemes
./scripts/dev-build.sh list

# Show help
./scripts/dev-build.sh help
```

### CI/CD Pipeline

The repository includes a properly configured GitHub Actions workflow (`.github/workflows/ci.yml`) that:

1. Runs on `macos-latest` runners with full Xcode access
2. Uses the latest stable Xcode version
3. Resolves Swift package dependencies
4. Builds and tests the iOS application
5. Uploads test logs and crash reports


### Enhanced Development Script

The `scripts/dev-build.sh` script has been enhanced with Swift 6 concurrency support:

```bash
# Run all development checks (recommended)
./scripts/dev-build.sh all

# Check Swift 6 concurrency patterns
./scripts/dev-build.sh concurrency

# Run development tests (syntax + concurrency)
./scripts/dev-build.sh test
```

**Enhanced Features:**
- Swift 6 concurrency pattern detection
- DispatchQueue anti-pattern warnings  
- Non-exhaustive catch block detection
- @MainActor timer usage validation
- Early warning system for compilation issues


### Development Workflow

1. **Local Development:**
   - On macOS: Use Xcode or xcodebuild commands directly<<<<<<< copilot/fix-11
   - On other platforms: Use `./scripts/dev-build.sh` for syntax and concurrency checking

2. **Real-time Error Checking:**
   - Enhanced dev script provides Swift 6 concurrency issue detection
   - The CI pipeline provides comprehensive error checking with every push
   - Local syntax checking is available via the development script
   - VS Code extensions provide additional Swift language support

3. **Testing:**
   - Full test suite runs in CI/CD on macOS with iOS Simulator
   - Core logic can be syntax-checked locally on any platform
   - Test files are validated for syntax errors
   - Swift 6 concurrency patterns are validated locally

### Merge Conflict Resolution

If you encounter merge conflicts with `scripts/dev-build.sh`, use the provided helper:

```bash
# Resolve merge conflicts and preserve enhanced features
./scripts/merge-helper.sh
```

This ensures the enhanced Swift 6 concurrency features are preserved during merges.


### File Structure

```
zpod.xcodeproj/     # Xcode project file
zpod/               # Main source code
zpodTests/          # Unit tests
scripts/dev-build.sh          # Development build script
.github/workflows/ci.yml      # CI/CD configuration
Package.swift                 # Swift Package Manager (experimental)
```

### Known Limitations

- SwiftUI, SwiftData, and Combine are not available on non-Apple platforms
- Full compilation and testing requires macOS with Xcode
- The Package.swift is experimental and excludes iOS-specific frameworks
- AVFoundation and other Apple frameworks are iOS/macOS only

### Next Steps

1. The CI configuration is correct and working
2. Development scripts provide syntax checking across platforms
3. Real-time error feedback is available through:
   - CI/CD pipeline for comprehensive testing
   - Local syntax checking for immediate feedback
   - VS Code extensions for editor integration

The issue appears to be resolved - you now have access to development tools that provide xcodebuild-like functionality in any environment, with the full power of xcodebuild available through the CI/CD pipeline.
#!/bin/bash

# dev-build.sh - Development build script for zpod
# Provides xcodebuild-like functionality for development environments without Xcode

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_FILES_DIR="$PROJECT_ROOT/zpod"
TEST_FILES_DIR="$PROJECT_ROOT/zpodTests"

echo -e "${BLUE}🔨 zPodcastAddict Development Build Script${NC}"
echo "Project root: $PROJECT_ROOT"
echo

# Function to print section headers
print_section() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}


# Function to check Swift syntax and concurrency

check_swift_syntax() {
    print_section "Checking Swift Syntax"
    
    local error_count=0
    
    # Check main source files
    if [[ -d "$SWIFT_FILES_DIR" ]]; then
        echo "Checking main source files..."
        while IFS= read -r -d '' file; do
            echo "Checking: $(basename "$file")"

            # Basic syntax check
            if ! swift -frontend -parse "$file" > /dev/null 2>&1; then
                echo -e "${RED}❌ Syntax error in $file${NC}"
                swift -frontend -parse "$file" 2>&1 | head -10
                ((error_count++))
            else
                echo -e "${GREEN}✅ $(basename "$file")${NC}"
            fi
        done < <(find "$SWIFT_FILES_DIR" -name "*.swift" -type f -print0)
    fi
    
    # Check test files
    if [[ -d "$TEST_FILES_DIR" ]]; then
        echo
        echo "Checking test files..."
        while IFS= read -r -d '' file; do
            echo "Checking: $(basename "$file")"
            if ! swift -frontend -parse "$file" > /dev/null 2>&1; then
                echo -e "${RED}❌ Syntax error in $file${NC}"
                swift -frontend -parse "$file" 2>&1 | head -10
                ((error_count++))
            else
                echo -e "${GREEN}✅ $(basename "$file")${NC}"
            fi
        done < <(find "$TEST_FILES_DIR" -name "*.swift" -type f -print0)
    fi
    
    echo
    if [[ $error_count -eq 0 ]]; then
        echo -e "${GREEN}🎉 All Swift files passed syntax check!${NC}"
    else
        echo -e "${RED}❌ Found $error_count syntax errors${NC}"
        return 1
    fi
}


# Function to check for common Swift 6 concurrency issues
check_concurrency_patterns() {
    print_section "Checking Swift 6 Concurrency Patterns"
    
    local issues_found=0
    
    echo "Checking for common concurrency anti-patterns..."
    
    # Check for DispatchQueue.global().async without proper isolation
    if grep -rn "DispatchQueue\.global()\.async" "$SWIFT_FILES_DIR" "$TEST_FILES_DIR" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Found DispatchQueue.global().async - consider using Task.detached or proper actor isolation${NC}"
        ((issues_found++))
    fi
    
    # Check for DispatchQueue.main.async without @MainActor context
    if grep -rn "DispatchQueue\.main\.async" "$SWIFT_FILES_DIR" "$TEST_FILES_DIR" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Found DispatchQueue.main.async - consider using Task { @MainActor in ... }${NC}"
        ((issues_found++))
    fi
    
    # Check for potential non-exhaustive catch blocks
    echo
    echo "Checking for potential non-exhaustive error handling..."
    local catch_blocks
    catch_blocks=$(grep -rn "} catch {" "$SWIFT_FILES_DIR" "$TEST_FILES_DIR" 2>/dev/null || true)
    
    if [[ -n "$catch_blocks" ]]; then
        # For now, just note the presence - this is often acceptable when error is used
        echo -e "${GREEN}✅ Generic catch blocks found but may be acceptable when error is used${NC}"
    fi
    
    # Check for @MainActor classes without proper async task patterns
    echo
    echo "Checking for async patterns in @MainActor classes..."
    local mainactor_files
    mainactor_files=$(grep -l "@MainActor" "$SWIFT_FILES_DIR"/*.swift 2>/dev/null || true)
    
    if [[ -n "$mainactor_files" ]]; then
        for file in $mainactor_files; do
            if grep -q "Timer\.scheduledTimer" "$file" && ! grep -q "Task { @MainActor" "$file"; then
                echo -e "${YELLOW}⚠️  File $(basename "$file") has Timer usage without proper @MainActor task wrapping${NC}"
                ((issues_found++))
            fi
        done
    fi
    
    # Check for nonisolated init in @MainActor classes that set properties
    echo
    echo "Checking for actor isolation violations..."
    while IFS= read -r file; do
        if grep -q "@MainActor" "$file" && grep -q "nonisolated init" "$file"; then
            if grep -q "self\." "$file" | grep -A5 -B5 "nonisolated init" "$file" | grep -q "self\."; then
                echo -e "${YELLOW}⚠️  File $(basename "$file") has nonisolated init setting properties in @MainActor class${NC}"
                echo "    Consider removing 'nonisolated' from the initializer"
                ((issues_found++))
            fi
        fi
    done < <(find "$SWIFT_FILES_DIR" -name "*.swift" 2>/dev/null || true)
    
    # Check for potential actor boundary crossing issues
    echo
    echo "Checking for potential actor boundary crossing issues..."
    while IFS= read -r file; do
        # Look for Task.detached blocks that access parameter properties directly  
        if grep -q "Task\.detached" "$file"; then
            # Check if there's parameter property access inside Task blocks
            if grep -A10 "Task\.detached" "$file" | grep -q "task\." || grep -A10 "Task\.detached" "$file" | grep -q "\.id"; then
                echo -e "${YELLOW}⚠️  File $(basename "$file") may have actor boundary crossing - extract properties before Task.detached${NC}"
                echo "    Consider extracting parameter properties to local variables before async closures"
                ((issues_found++))
            fi
        fi
    done < <(find "$SWIFT_FILES_DIR" -name "*.swift" 2>/dev/null || true)
    
    # Check for potential data race patterns in Task.detached blocks
    echo
    echo "Checking for data race patterns in Task.detached blocks..."
    while IFS= read -r file; do
        if grep -q "Task\.detached" "$file"; then
            # Check for object creation inside Task.detached that gets sent to @MainActor
            local task_detached_lines
            task_detached_lines=$(grep -n "Task\.detached" "$file" | cut -d: -f1)
            for line_num in $task_detached_lines; do
                # Look for DownloadProgress creation patterns within 20 lines after Task.detached
                local end_line=$((line_num + 20))
                if sed -n "${line_num},${end_line}p" "$file" | grep -q "DownloadProgress(taskId:.*progress:" && \
                   sed -n "${line_num},${end_line}p" "$file" | grep -q "@MainActor"; then
                    echo -e "${GREEN}✅  File $(basename "$file") uses correct pattern: object creation in Task.detached, then send to @MainActor${NC}"
                fi
                
                # Check for potentially problematic patterns
                if sed -n "${line_num},${end_line}p" "$file" | grep -q "let.*Progress.*=" && \
                   sed -n "${line_num},${end_line}p" "$file" | grep -q "taskId.*progress" && \
                   ! sed -n "${line_num},${end_line}p" "$file" | grep -q "currentTaskId\|progressValue"; then
                    echo -e "${YELLOW}⚠️  File $(basename "$file") may have data race risk - ensure object creation uses local variables${NC}"
                    echo "    Consider using local copies like 'currentTaskId' and 'progressValue'"
                    ((issues_found++))
                fi
            done
        fi
    done < <(find "$SWIFT_FILES_DIR" "$TEST_FILES_DIR" -name "*.swift" 2>/dev/null || true)
    
    # Check for object creation inside @MainActor Task blocks that could cause data races  
    echo
    echo "Checking for object creation data race patterns..."
    while IFS= read -r file; do
        # Check for potential misused patterns where objects created outside are sent across boundaries
        if grep -q "Task\.detached" "$file"; then
            local content
            content=$(cat "$file")
            # Look for the old anti-pattern: object created in Task.detached and sent
            if echo "$content" | grep -A10 "Task\.detached" | grep -B3 "Task { @MainActor" | grep -B1 "\.send(" | grep -q "let.*=.*DownloadProgress"; then
                echo -e "${YELLOW}⚠️  File $(basename "$file") may be using old pattern - creating objects in Task.detached before sending${NC}"
                echo "    Consider creating objects inside @MainActor Task block to avoid data races"
                ((issues_found++))
            fi
        fi
    done < <(find "$SWIFT_FILES_DIR" "$TEST_FILES_DIR" -name "*.swift" 2>/dev/null || true)
    
    echo
    if [[ $issues_found -eq 0 ]]; then
        echo -e "${GREEN}✅ No obvious concurrency anti-patterns found${NC}"
    else
        echo -e "${YELLOW}⚠️  Found $issues_found potential concurrency issues (warnings only)${NC}"
        echo "    These are potential issues that may cause Swift 6 compilation errors"
        echo "    Review the flagged patterns and consider using Swift 6 concurrency best practices"
    fi
}


# Function to show project info
show_project_info() {
    print_section "Project Information"
    
    echo "Swift version: $(swift --version | head -1)"
    echo "Platform: $(uname -s) $(uname -m)"
    
    if [[ -f "$PROJECT_ROOT/zpod.xcodeproj/project.pbxproj" ]]; then
        echo -e "${GREEN}✅ Xcode project found${NC}"
    else
        echo -e "${YELLOW}⚠️  Xcode project not found${NC}"
    fi
    
    local swift_file_count
    swift_file_count=$(find "$PROJECT_ROOT" -name "*.swift" -type f | wc -l)
    echo "Swift files found: $swift_file_count"
    
    echo
}

# Function to simulate xcodebuild list
simulate_xcodebuild_list() {
    print_section "Project Targets and Schemes (simulated)"
    
    echo "Targets:"
    echo "  - zpod"
    echo "  - zpodTests" 
    echo "  - zpodUITests"
    echo
    echo "Schemes:"
    echo "  - zpod"
    echo
    echo "Note: This is simulated information. Use 'xcodebuild -list' on macOS for actual details."
    echo
}

# Function to run Swift Package Manager commands (if applicable)
run_spm_commands() {
    print_section "Swift Package Manager Commands"
    
    if [[ -f "$PROJECT_ROOT/Package.swift" ]]; then
        echo "Package.swift found. Running SPM commands..."
        
        echo "Describing package..."
        swift package describe || echo "Package describe failed"
        
        echo
        echo "Note: SPM build may fail due to iOS-specific dependencies"
        echo "This is expected and normal for iOS projects on non-macOS platforms"
        
    else
        echo "No Package.swift found - this is normal for Xcode-only projects"
    fi
    echo
}

# Function to check CI configuration
check_ci_config() {
    print_section "CI/CD Configuration Check"
    
    local ci_file="$PROJECT_ROOT/.github/workflows/ci.yml"
    if [[ -f "$ci_file" ]]; then
        echo -e "${GREEN}✅ CI configuration found${NC}"
        echo "Checking CI configuration..."
        
        if grep -q "xcodebuild" "$ci_file"; then
            echo -e "${GREEN}✅ xcodebuild commands found in CI${NC}"
        else
            echo -e "${RED}❌ No xcodebuild commands found in CI${NC}"
        fi
        
        if grep -q "macos-latest" "$ci_file"; then
            echo -e "${GREEN}✅ macOS runner configured${NC}"
        else
            echo -e "${YELLOW}⚠️  Non-macOS runner detected${NC}"
        fi
        
        if grep -q "setup-xcode" "$ci_file"; then
            echo -e "${GREEN}✅ Xcode setup action found${NC}"
        else
            echo -e "${YELLOW}⚠️  No Xcode setup action found${NC}"
        fi
        
    else
        echo -e "${RED}❌ No CI configuration found${NC}"
    fi
    echo
}

# Function to run available tests
run_syntax_tests() {
    print_section "Running Development Tests"
    
    echo "Note: Full test suite requires Xcode on macOS"
    echo "Performing available syntax and basic checks..."
    echo
    
    check_swift_syntax
    check_concurrency_patterns

}

# Function to show xcodebuild equivalent commands
show_xcodebuild_commands() {
    print_section "xcodebuild Equivalent Commands"
    
    echo "For macOS with Xcode installed, use these commands:"
    echo
    echo "# Check Xcode version"
    echo "xcodebuild -version"
    echo
    echo "# List targets and schemes"
    echo "xcodebuild -list -project zpod.xcodeproj"
    echo
    echo "# Build project"
    echo "xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator"
    echo
    echo "# Run tests"
    echo "xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.2' test"
    echo
    echo "# Clean build"
    echo "xcodebuild -project zpod.xcodeproj -scheme zpod clean"
    echo
    echo "On non-macOS platforms, this script provides syntax checking and basic validation."
    echo
}

# Main script logic
case "${1:-help}" in
    "syntax")
        check_swift_syntax
        ;;
    "concurrency")
        check_concurrency_patterns
        ;;
    "info")
        show_project_info
        ;;
    "list")
        simulate_xcodebuild_list
        ;;
    "test")
        run_syntax_tests
        ;;
    "spm")
        run_spm_commands
        ;;
    "ci")
        check_ci_config
        ;;
    "xcode")
        show_xcodebuild_commands
        ;;
    "all")
        show_project_info
        check_ci_config
        simulate_xcodebuild_list
        check_swift_syntax
        check_concurrency_patterns
        run_spm_commands
        ;;
    "help"|*)
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "  syntax    - Check Swift syntax for all files"
        echo "  concurrency - Check for Swift 6 concurrency patterns"
        echo "  info      - Show project information"
        echo "  list      - Show targets and schemes (simulated)"
        echo "  test      - Run development tests (syntax + concurrency)"
        echo "  spm       - Run Swift Package Manager commands"
        echo "  ci        - Check CI/CD configuration"
        echo "  xcode     - Show xcodebuild equivalent commands"
        echo "  all       - Run all checks"
        echo "  help      - Show this help message"
        echo
        echo "This script provides xcodebuild-like functionality for development"
        echo "environments without Xcode. For full building and testing, use"
        echo "Xcode on macOS or the CI/CD pipeline."
        echo
        echo "See DEVELOPMENT.md for detailed usage instructions."
        ;;
esac
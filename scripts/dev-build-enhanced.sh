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
    
    # Check all Swift files in the project
    local all_swift_files
    all_swift_files=$(find "$PROJECT_ROOT" -name "*.swift" -type f | grep -v ".build" | grep -v "build" | grep -v ".swiftpm")
    
    echo "Checking Swift files for syntax errors..."
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            echo "Checking: $(basename "$file")"
            # Basic syntax check
            if ! swift -frontend -parse "$file" > /dev/null 2>&1; then
                echo -e "${RED}❌ Syntax error in $file${NC}"
                swift -frontend -parse "$file" 2>&1 | head -10
                ((error_count++))
            else
                echo -e "${GREEN}✅ $(basename "$file")${NC}"
            fi
        fi
    done <<< "$all_swift_files"
    
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
    if grep -rn "DispatchQueue\.global()\.async" "$PROJECT_ROOT" --include="*.swift" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Found DispatchQueue.global().async - consider using Task.detached or proper actor isolation${NC}"
        ((issues_found++))
    fi
    
    # Check for DispatchQueue.main.async without @MainActor context
    if grep -rn "DispatchQueue\.main\.async" "$PROJECT_ROOT" --include="*.swift" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Found DispatchQueue.main.async - consider using Task { @MainActor in ... }${NC}"
        ((issues_found++))
    fi
    
    # Check for potential non-exhaustive catch blocks
    echo
    echo "Checking for potential non-exhaustive error handling..."
    while IFS= read -r line; do
        if [[ "$line" =~ catch[[:space:]]*\{ ]]; then
            echo -e "${YELLOW}⚠️  Found generic catch block: $line${NC}"
            echo "    Consider handling specific error types when possible"
            ((issues_found++))
        fi
    done < <(grep -rn "} catch {" "$PROJECT_ROOT" --include="*.swift" 2>/dev/null || true)
    
    # Check for @MainActor classes without proper async task patterns
    echo
    echo "Checking for async patterns in @MainActor classes..."
    local mainactor_files
    mainactor_files=$(grep -l "@MainActor" "$PROJECT_ROOT"/**/*.swift 2>/dev/null || true)
    
    if [[ -n "$mainactor_files" ]]; then
        for file in $mainactor_files; do
            if grep -q "Timer\.scheduledTimer" "$file" && ! grep -q "Task { @MainActor" "$file"; then
                echo -e "${YELLOW}⚠️  File $(basename "$file") has Timer usage without proper @MainActor task wrapping${NC}"
                ((issues_found++))
            fi
        done
    fi
    
    echo
    if [[ $issues_found -eq 0 ]]; then
        echo -e "${GREEN}✅ No obvious concurrency anti-patterns found${NC}"
    else
        echo -e "${YELLOW}⚠️  Found $issues_found potential concurrency issues (warnings only)${NC}"
        echo "    These are potential issues that may cause Swift 6 compilation errors"
        echo "    Review the flagged patterns and consider using Swift 6 concurrency best practices"
    fi
}

# Function to check for SwiftUI syntax issues
check_swiftui_patterns() {
    print_section "Checking SwiftUI Syntax Patterns"
    
    local issues_found=0
    
    echo "Checking for common SwiftUI syntax issues..."
    
    # Check for computed properties that return different view types without @ViewBuilder
    echo "Checking for missing @ViewBuilder annotations..."
    local view_files
    view_files=$(grep -l "some View" "$PROJECT_ROOT" --include="*.swift" -r 2>/dev/null || true)
    
    if [[ -n "$view_files" ]]; then
        for file in $view_files; do
            # Look for private computed properties (not body property) with conditional returns that lack @ViewBuilder
            local var_lines
            var_lines=$(grep -n "private var.*: some View" "$file" | cut -d: -f1)
            for line_num in $var_lines; do
                # Check if the line before has @ViewBuilder annotation
                local prev_line_num=$((line_num - 1))
                local has_viewbuilder
                has_viewbuilder=$(sed -n "${prev_line_num}p" "$file" | grep "@ViewBuilder" || true)
                
                if [[ -z "$has_viewbuilder" ]]; then
                    # Get the property content (simplified check)
                    local property_content
                    property_content=$(sed -n "${line_num},+20p" "$file" | grep -E "(if |else |switch |case )" || true)
                    if [[ -n "$property_content" ]]; then
                        echo -e "${YELLOW}⚠️  File $(basename "$file"):$line_num private computed property may need @ViewBuilder for conditional views${NC}"
                        ((issues_found++))
                    fi
                fi
            done
        done
    fi
    
    # Check for trailing closures that might cause parsing issues
    echo "Checking for potential SwiftUI closure syntax issues..."
    if grep -rn "}\s*\..*{\s*$" "$PROJECT_ROOT" --include="*.swift" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Found potential closure syntax issues - check modifier chaining${NC}"
        ((issues_found++))
    fi
    
    # Check for NavigationView usage (deprecated in iOS 16+)
    if grep -rn "NavigationView" "$PROJECT_ROOT" --include="*.swift" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Found NavigationView usage - consider using NavigationStack for iOS 16+${NC}"
        ((issues_found++))
    fi
    
    # Check for unmatched braces (simplified check)
    echo "Checking for potential unmatched braces..."
    local swift_files
    swift_files=$(find "$PROJECT_ROOT" -name "*.swift" -type f | grep -v ".build" | grep -v "build")
    
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            local open_braces
            local close_braces
            open_braces=$(grep -o "{" "$file" 2>/dev/null | wc -l)
            close_braces=$(grep -o "}" "$file" 2>/dev/null | wc -l)
            
            if [[ $open_braces -ne $close_braces ]]; then
                echo -e "${YELLOW}⚠️  File $(basename "$file") has unmatched braces: $open_braces open, $close_braces close${NC}"
                ((issues_found++))
            fi
        fi
    done <<< "$swift_files"
    
    echo
    if [[ $issues_found -eq 0 ]]; then
        echo -e "${GREEN}✅ No obvious SwiftUI syntax issues found${NC}"
    else
        echo -e "${YELLOW}⚠️  Found $issues_found potential SwiftUI syntax issues (warnings only)${NC}"
        echo "    These patterns may cause SwiftUI compilation errors"
        echo "    Review the flagged patterns and consider using proper SwiftUI syntax"
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
    check_swiftui_patterns
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
    "swiftui")
        check_swiftui_patterns
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
        check_swiftui_patterns
        check_concurrency_patterns
        run_spm_commands
        ;;
    "help"|*)
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "  syntax      - Check Swift syntax for all files"
        echo "  swiftui     - Check for SwiftUI syntax patterns and potential issues"
        echo "  concurrency - Check for Swift 6 concurrency patterns"
        echo "  info        - Show project information"
        echo "  list        - Show targets and schemes (simulated)"
        echo "  test        - Run development tests (syntax + swiftui + concurrency)"
        echo "  spm         - Run Swift Package Manager commands"
        echo "  ci          - Check CI/CD configuration"
        echo "  xcode       - Show xcodebuild equivalent commands"
        echo "  all         - Run all checks"
        echo "  help        - Show this help message"
        echo
        echo "This script provides xcodebuild-like functionality for development"
        echo "environments without Xcode. For full building and testing, use"
        echo "Xcode on macOS or the CI/CD pipeline."
        echo
        echo "See DEVELOPMENT.md for detailed usage instructions."
        ;;
esac
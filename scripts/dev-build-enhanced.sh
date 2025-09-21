#!/bin/bash

# dev-build-enhanced.sh - Lightweight Swift syntax/concurrency checks for non-macOS environments

set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_ROOT}/.." && pwd)"

# shellcheck source=lib/logging.sh
source "${SCRIPT_ROOT}/lib/logging.sh"
# shellcheck source=lib/common.sh
source "${SCRIPT_ROOT}/lib/common.sh"

PROJECT_ROOT="$REPO_ROOT"
SWIFT_FILES_DIR="${REPO_ROOT}/zpod"
TEST_FILES_DIR="${REPO_ROOT}/zpodTests"

print_section() {
    log_section "$@"
}

log_section "🔨 zPodcastAddict Development Build Script"
log_info "Project root: ${REPO_ROOT}"

# Function to check Swift syntax and concurrency
check_swift_syntax() {
    log_section "Checking Swift Syntax"
    
    local error_count=0
    
    # Check all Swift files in the project
    local all_swift_files
    all_swift_files=$(find "$PROJECT_ROOT" -name "*.swift" -type f | grep -v ".build" | grep -v "build" | grep -v ".swiftpm")
    
    echo "Checking Swift files for syntax errors..."
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            log_info "Checking: $(basename "$file")"
            # Basic syntax check
            if ! swift -frontend -parse "$file" > /dev/null 2>&1; then
                log_error "Syntax error in $file"
                swift -frontend -parse "$file" 2>&1 | head -10
                ((error_count++))
            else
                log_success "$(basename "$file")"
            fi
        fi
    done <<< "$all_swift_files"
    
    echo
    if [[ $error_count -eq 0 ]]; then
        log_success "All Swift files passed syntax check"
    else
        log_error "Found $error_count syntax errors"
        return 1
    fi
}

# Function to check for common Swift 6 concurrency issues
check_concurrency_patterns() {
    log_section "Checking Swift 6 Concurrency Patterns"
    
    local issues_found=0
    
    log_info "Checking for common concurrency anti-patterns..."
    
    # Check for DispatchQueue.global().async without proper isolation
    if grep -rn "DispatchQueue\.global()\.async" "$PROJECT_ROOT" --include="*.swift" 2>/dev/null; then
        log_warn "Found DispatchQueue.global().async - consider using Task.detached or proper actor isolation"
        ((issues_found++))
    fi
    
    # Check for DispatchQueue.main.async without @MainActor context
    if grep -rn "DispatchQueue\.main\.async" "$PROJECT_ROOT" --include="*.swift" 2>/dev/null; then
        log_warn "Found DispatchQueue.main.async - consider using Task { @MainActor in ... }"
        ((issues_found++))
    fi
    
    # Check for potential non-exhaustive catch blocks
    echo
    log_info "Checking for potential non-exhaustive error handling..."
    while IFS= read -r line; do
        if [[ "$line" =~ catch[[:space:]]*\{ ]]; then
            log_warn "Found generic catch block: $line"
            log_info "    Consider handling specific error types when possible"
            ((issues_found++))
        fi
    done < <(grep -rn "} catch {" "$PROJECT_ROOT" --include="*.swift" 2>/dev/null || true)
    
    # Check for @MainActor classes without proper async task patterns
    echo
    log_info "Checking for async patterns in @MainActor classes..."
    local mainactor_files
    mainactor_files=$(grep -l "@MainActor" "$PROJECT_ROOT"/**/*.swift 2>/dev/null || true)
    
    if [[ -n "$mainactor_files" ]]; then
        for file in $mainactor_files; do
            if grep -q "Timer\.scheduledTimer" "$file" && ! grep -q "Task { @MainActor" "$file"; then
                log_warn "File $(basename "$file") has Timer usage without proper @MainActor task wrapping"
                ((issues_found++))
            fi
        done
    fi
    
    echo
    if [[ $issues_found -eq 0 ]]; then
        log_success "No obvious concurrency anti-patterns found"
    else
        log_warn "Found $issues_found potential concurrency issues (warnings only)"
        log_info "    Review the flagged patterns and consider Swift 6 concurrency best practices"
    fi
}

# Function to check for SwiftUI syntax issues
check_swiftui_patterns() {
    log_section "Checking SwiftUI Syntax Patterns"
    
    local issues_found=0
    
    log_info "Checking for common SwiftUI syntax issues..."
    
    # Check for computed properties that return different view types without @ViewBuilder
    log_info "Checking for missing @ViewBuilder annotations..."
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
                        log_warn "File $(basename "$file"):$line_num private computed property may need @ViewBuilder"
                        ((issues_found++))
                    fi
                fi
            done
        done
    fi
    
    # Check for trailing closures that might cause parsing issues
    log_info "Checking for potential SwiftUI closure syntax issues..."
    if grep -rn "}\s*\..*{\s*$" "$PROJECT_ROOT" --include="*.swift" 2>/dev/null; then
        log_warn "Found potential closure syntax issues - check modifier chaining"
        ((issues_found++))
    fi
    
    # Check for NavigationView usage (deprecated in iOS 16+)
    if grep -rn "NavigationView" "$PROJECT_ROOT" --include="*.swift" 2>/dev/null; then
        log_warn "Found NavigationView usage - consider NavigationStack for iOS 16+"
        ((issues_found++))
    fi
    
    # Check for unmatched braces (simplified check)
    log_info "Checking for potential unmatched braces..."
    local swift_files
    swift_files=$(find "$PROJECT_ROOT" -name "*.swift" -type f | grep -v ".build" | grep -v "build")
    
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            local open_braces
            local close_braces
            open_braces=$(grep -o "{" "$file" 2>/dev/null | wc -l)
            close_braces=$(grep -o "}" "$file" 2>/dev/null | wc -l)
            
            if [[ $open_braces -ne $close_braces ]]; then
                log_warn "File $(basename "$file") has unmatched braces: $open_braces open, $close_braces close"
                ((issues_found++))
            fi
        fi
    done <<< "$swift_files"
    
    echo
    if [[ $issues_found -eq 0 ]]; then
        log_success "No obvious SwiftUI syntax issues found"
    else
        log_warn "Found $issues_found potential SwiftUI syntax issues (warnings only)"
        log_info "    Review the flagged patterns and consider using proper SwiftUI syntax"
    fi
}

# Function to show project info
show_project_info() {
    log_section "Project Information"
    log_info "Swift version: $(swift --version | head -1)"
    log_info "Platform: $(uname -s) $(uname -m)"

    if [[ -f "$PROJECT_ROOT/zpod.xcodeproj/project.pbxproj" ]]; then
        log_success "Xcode project found"
    else
        log_warn "Xcode project not found"
    fi

    local swift_file_count
    swift_file_count=$(find "$PROJECT_ROOT" -name "*.swift" -type f | wc -l)
    log_info "Swift files found: $swift_file_count"
    echo
}

# Function to simulate xcodebuild list
simulate_xcodebuild_list() {
    log_section "Project Targets and Schemes (simulated)"
    log_info "Targets: zpod, zpodTests, zpodUITests"
    log_info "Schemes: zpod"
    log_info "Note: Use 'xcodebuild -list' on macOS for actual details"
    echo
}

# Function to run Swift Package Manager commands (if applicable)
run_spm_commands() {
    log_section "Swift Package Manager Commands"
    if [[ -f "$PROJECT_ROOT/Package.swift" ]]; then
        log_info "Package.swift found. Running 'swift package describe'..."
        swift package describe || log_warn "Package describe failed"
        log_warn "SPM build may fail due to iOS-specific dependencies on non-macOS platforms"
    else
        log_warn "No Package.swift found - expected for Xcode-only projects"
    fi
    echo
}

# Function to check CI configuration
check_ci_config() {
    log_section "CI/CD Configuration Check"

    local ci_file="$PROJECT_ROOT/.github/workflows/ci.yml"
    if [[ -f "$ci_file" ]]; then
        log_success "CI configuration found"
        if grep -q "xcodebuild" "$ci_file"; then
            log_success "xcodebuild commands present in CI"
        else
            log_warn "No xcodebuild commands found in CI"
        fi

        if grep -q "macos-latest" "$ci_file"; then
            log_success "macOS runner configured"
        else
            log_warn "Non-macOS runner detected"
        fi

        if grep -q "setup-xcode" "$ci_file"; then
            log_success "Xcode setup action found"
        else
            log_warn "No Xcode setup action found"
        fi
    else
        log_error "No CI configuration found"
    fi
    echo
}

# Function to run available tests
run_syntax_tests() {
    log_section "Running Development Tests"

    log_info "Note: Full test suite requires Xcode on macOS"
    log_info "Performing available syntax and basic checks..."
    echo
    
    check_swift_syntax
    check_swiftui_patterns
    check_concurrency_patterns
}

# Function to show xcodebuild equivalent commands
show_xcodebuild_commands() {
    log_section "xcodebuild Equivalent Commands"
    log_info "For macOS with Xcode installed, the following commands are commonly used:"
    log_info "  xcodebuild -version"
    log_info "  xcodebuild -list -project zpod.xcodeproj"
    log_info "  xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator"
    log_info "  xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.2' test"
    log_info "  xcodebuild -project zpod.xcodeproj -scheme zpod clean"
    log_info "On non-macOS platforms, this script provides syntax checking and basic validation."
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

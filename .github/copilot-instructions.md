# Coding and Testing Best Practices for zPod

## Coding Best Practices for zPod
- Always follow TDD: write failing tests first, then implement code, then refactor.
- As you do TDD, build both unit tests and, when possible, integration tests.
- Refactor tests and/or add integration tests if gaps are found.
- Reference the spec files (Given/When/Then) and ensure the code matches the expectations.

## Requirements/Specifications
- as you read attempt to do each issues, make sure you are referencing the specifications
- all specificaitons can be found in the spec folder and are given when then format
- tests should follow these specifications to ensure they work correctly to the specification

# Swift 6 Best Practices for zPod

## Swift 6 Concurrency & Sendable
- Always use `async`/`await` for asynchronous operations instead of completion handlers.
- Mark types as `Sendable` when they can be safely passed across concurrency domains.
- Use `@preconcurrency import` for libraries not yet updated for Swift 6 concurrency.
- Prefer `@MainActor` for UI-related classes and methods.
- Use `nonisolated` for methods that don't need actor isolation.
- Handle concurrency warnings and make explicit isolation decisions.

## Actor Usage
- Use actors for mutable shared state that needs thread-safe access.
- Prefer `@MainActor` for view models and UI controllers.
- Use global actors sparingly and only when appropriate.
- Design actor interfaces to minimize cross-actor calls.
- Use `nonisolated` for computed properties that don't access mutable state.

## Error Handling
- Use typed throws (`throws(SpecificError)`) when possible for better error handling.
- Prefer Result types for complex error scenarios.
- Handle errors at appropriate levels in the call stack.
- Use custom error types that conform to `LocalizedError` for user-facing errors.

## Testing Best Practices

### Test Structure and Organization
- Use descriptive test method names that explain the scenario: `testAcceptanceCriteria1_CascadingResolution()`.
- Organize tests with clear Given/When/Then structure using comments.
- Group related tests using `// MARK:` comments for better navigation.
- Use separate UserDefaults suites for each test to ensure isolation.

### Async Testing Patterns
- Use `async` test methods for testing async code: `func testExample() async`.
- Use `await` for all async operations in tests.
- Set up and tear down async resources properly in `setUp()` and `tearDown()`.

### Combine Testing
- Use `Set<AnyCancellable>` to manage test subscriptions.
- Store publishers in instance variables for proper lifecycle management.
- Always call `store(in: &cancellables)` to prevent memory leaks.
- Test both published properties and custom publishers.

### Test Data Management
- Use unique UserDefaults suite names per test: `UserDefaults(suiteName: "test-criteria-1")`.
- Always clean up test data: `userDefaults.removePersistentDomain(forName: "test-criteria-1")`.
- Create fresh instances for each test to avoid state pollution.

### Validation Testing
- Test boundary conditions and invalid inputs.
- Verify that invalid values are properly clamped or rejected.
- Test both positive and negative scenarios.
- Include edge cases in your test coverage.

### Integration Testing
- Test end-to-end scenarios that mirror real user workflows.
- Verify that settings persist across app restarts.
- Test cascading behavior (global → per-podcast overrides).
- Validate backward compatibility with existing APIs.

## Memory Management
- Use `weak` references to break retain cycles in closures and delegates.
- Prefer `unowned` only when you're certain the referenced object will outlive the current context.
- Use `@escaping` closures judiciously and always consider memory implications.
- Avoid creating retain cycles with async/await patterns.

## SwiftUI Best Practices
- Use `@State` for local view state.
- Use `@StateObject` for creating and owning observable objects.
- Use `@ObservedObject` for objects owned elsewhere.
- Use `@EnvironmentObject` for dependency injection.
- Keep view bodies lightweight and extract complex logic into methods or computed properties.

## Code Organization
- Use extensions to organize code by functionality.
- Keep related functionality grouped together.
- Use `// MARK:` comments for clear code sections.
- Prefer composition over inheritance where possible.

## Modularization & Package Boundaries
- Standard module set (initial): CoreModels, FeedParsing, Networking, Persistence, SettingsDomain, PlaybackEngine, SharedUtilities, TestSupport. Optional feature UI modules (e.g., LibraryFeature, SearchFeature, PlayerFeature).
- Dependency direction: Utilities → CoreModels → (Networking, Persistence, FeedParsing) → SettingsDomain → Feature UIs → App. PlaybackEngine is used by Feature UIs/App.
- Concurrency boundaries: Mark cross-package value types `Sendable`; use actors for shared mutable state; limit `@MainActor` to UI modules; define async protocols at seams; minimize cross-actor hops.
- Access control: Keep public surfaces small; prefer `internal` by default; expose protocols for cross-package seams; document isolation and error types on public APIs.
- Testing: Each package has its own test target; use TestSupport for fixtures/fakes; prefer protocol-driven injection for Networking/Persistence.
- Platform/resources: Keep CoreModels/Parsing platform-agnostic; gate AVFoundation code with `#if canImport(AVFoundation)`; keep SwiftUI previews in the app or a PreviewSupport target.
- Migration path (incremental): 1) Extract CoreModels + TestSupport; 2) Extract Persistence + SettingsDomain; 3) Extract Networking + FeedParsing; 4) Optionally extract PlaybackEngine; split feature UIs later if needed.
- Acceptance criteria: App builds, tests pass; UI targets do not depend directly on Persistence/Networking.

## Property Wrappers
- Use `@Published` for properties that should trigger UI updates.
- Use custom property wrappers for common patterns (like UserDefaults storage).
- Always consider thread safety when creating custom property wrappers.

## Combine Framework
- Use `@preconcurrency import Combine` until Combine is fully Swift 6 compatible.
- Prefer async/await over Combine for simple async operations.
- Use Combine for complex data transformation and UI binding scenarios.
- Always manage subscription lifecycle properly.

## Performance Considerations
- Use `lazy` properties for expensive computations that may not be needed.
- Prefer value types (structs) over reference types (classes) when appropriate.
- Use `@inlinable` for small, frequently called functions.
- Consider using `@frozen` for public structs that won't change.

## API Design
- Use clear, descriptive parameter names.
- Prefer methods that return values over methods that modify state.
- Design APIs that are hard to misuse.
- Use default parameter values to reduce API surface area.
- Follow Swift naming conventions consistently.

## Documentation
- Use documentation comments (`///`) for public APIs.
- Include usage examples in documentation when helpful.
- Document preconditions and postconditions.
- Explain complex algorithms and business logic.

## Package Management
- Keep `Package.swift` dependencies up to date.
- Use specific version ranges rather than branch dependencies.
- Document why each dependency is needed.
- Regularly audit dependencies for security and maintenance status.

## Migration Guidelines
- When updating from older Swift versions, address all concurrency warnings.
- Test thoroughly when migrating async code.
- Update test patterns to match the new concurrency model.

## Project-Specific Guidelines
- Platform targeting: Build for iOS 18+ and watchOS 11+ only; use `.iOS(.v18)` and `.watchOS(.v11)` in manifests, scripts, and CI.
- Settings should cascade from global to per-podcast overrides.
- Use the SettingsManager pattern for centralized configuration.
- Validate settings values and clamp to safe ranges.
- Ensure settings persist across app restarts.
- Use Combine publishers for UI updates and change notifications.

## Logging All Updates
- For each issue, create a new dev-log in the `dev-log` directory at the root of this repository.
- Create and then update a dev-log for each issue you are working on.
- Continuously update the dev-log file for each issue: write your approach before code changes, then record progress as you go.
- Document your approach in bullet format with phases; update progress on each phase.
- Keep a log of changes with date and time stamps (Eastern Time).

## Git Commits
- For each set of updates, create git commits.
- Commits should include updates to the dev-log file for the related issue.
- After finishing changes for an issue, push the changes to GitHub.

## Logging in Application
- Use best practices of Swift 6/iOS for logging of errors, warnings, and issues.
- Use `OSLog` for application logging.

## Build Results
- For each build/test, create a file containing the raw test and build results.
- Name the log files `TestResults_<timestamp>_<what-you-tested>.log` (e.g., include a one-word package name when relevant).
- Put them in the `TestResults` subdirectory.
- Keep only the latest 3 build/test result files for any set of tests that you run.

# Development Environment Guide

## iOS and watchOS
- Build for iOS 18+ and watchOS 11+ only.
- Target device for simulator runs: iPhone 16 (or equivalent iOS 18 simulator).

## Xcodebuild Access and Development Tools

### macOS Development (Full xcodebuild Access)
If you're on macOS with Xcode installed, you can run:

```bash
# Check Xcode version
xcodebuild -version

# List available schemes and targets
xcodebuild -list -project zpod.xcodeproj

# Build the project (iOS Simulator)
xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator

# Run tests (update the device name/OS to an installed iOS 18 simulator)
xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' test

# Clean build
xcodebuild -project zpod.xcodeproj -scheme zpod clean
```

### Non-macOS Development (Alternative Tools)
For environments without Xcode (Linux, Windows, etc.), use the development script:

```bash
# Run all development checks (recommended)
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
The repository includes a GitHub Actions workflow that:
1. Runs on `macos-latest` with full Xcode access.
2. Uses the latest stable Xcode version.
3. Resolves Swift package dependencies.
4. Builds and tests the iOS application.
5. Uploads test logs and crash reports.

### Enhanced Development Script
The `scripts/dev-build.sh` script includes Swift 6 concurrency checks:

```bash
# Run all development checks (recommended)
./scripts/dev-build.sh all

# Check Swift 6 concurrency patterns
./scripts/dev-build.sh concurrency

# Run development tests (syntax + concurrency)
./scripts/dev-build.sh test
```

Enhanced features include:
- Swift 6 concurrency pattern detection.
- DispatchQueue anti-pattern warnings.
- Non-exhaustive catch block detection.
- `@MainActor` timer usage validation.
- Early warning system for compilation issues.

### Development Workflow
1. On macOS: Use Xcode or xcodebuild commands directly.
2. On other platforms: Use `./scripts/dev-build.sh` for syntax and concurrency checking.
3. Real-time error checking:
   - Enhanced dev script provides Swift 6 concurrency issue detection.
   - The CI pipeline provides comprehensive checks with every push.
   - Local syntax checking is available via the development script.
   - VS Code extensions can provide additional Swift language support.


### File Structure
```
zpod.xcodeproj/                # Xcode project file
zpod/                          # Main source code
zpodTests/                     # Unit tests
scripts/dev-build.sh           # Development build script
.github/workflows/ci.yml       # CI/CD configuration
Package.swift                  # Swift Package Manager (experimental)
```

### Known Limitations
- SwiftUI, SwiftData, and Combine are not available on non-Apple platforms.
- Full compilation and testing require macOS with Xcode.
- The `Package.swift` is experimental and excludes iOS-specific frameworks.
- AVFoundation and other Apple frameworks are iOS/macOS only.

### Next Steps
1. The CI configuration is correct and working.
2. Development scripts provide syntax checking across platforms.
3. Real-time error feedback is available through:
   - CI/CD pipeline for comprehensive testing.
   - Local syntax checking for immediate feedback.
   - Editor integration (VS Code extensions) for language support.

  
# Development Instructions for zPodcastAddict
<!-- these instructions came from the previous version of the copilot-instructions.md file. I have now combined them together into the .github directory -->

## Overview
These instructions outline the development process and standards for building the zPodcastAddict application.

## Requirements
1. **Language:** All code must be written in Swift.
2. **Target Platforms:** The application is to be built exclusively for iPhone (iOS), Apple Watch (watchOS), and CarPlay.
3. **Specification-Driven:** All features and functionality must follow the specification files found in the `spec` directory. Specifications are written in Given/When/Then format.

## Development Process
For each implementation step, the following process must be followed explicitly:
1. **Design Documentation:**
   - Document the design and approach for the step in `dev-log.md` before writing any tests or code.
2. **Test-Driven Development (TDD):**
   - Write tests based on the documented design and the Given/When/Then scenarios in the spec files before implementing any code.
3. **Specification Updates:**
   - If a Given/When/Then scenario is not robust enough to verify correct behavior, update the spec file first, then update the tests, then update the code.
4. **Implementation:**
   - Implement the code, ensuring it passes all tests.
5. **Version Control:**
   - If the code works and tests pass, add and commit the changes to git in a single commit with a clear message describing the change.
6. **Sync Confirmation:**
   - After committing, confirm whether the changes should be synced (pushed) to GitHub.

## SWIFT Coding Standards

    - All code must follow Swift best practices and conventions. Key standards include:
        - Use clear, descriptive names for variables, functions, and types.
        - Prefer value types (structs, enums) over reference types (classes) when possible.
        - Use optionals safely and avoid force-unwrapping.
        - Write concise, readable code with proper indentation and spacing.
        - Use access control (private, fileprivate, internal, public) appropriately.
        - Favor protocol-oriented programming and composition over inheritance.
        - Document code with comments and use Swift's documentation syntax (///).
        - Avoid using magic numbers or strings; use constants and enums.
        - Handle errors gracefully using Swift's error handling mechanisms (try/catch, Result type).
        - Write unit tests for all logic and maintain high test coverage.
        - Use mock objects in tests when verifying behavior involving external dependencies (e.g., network, storage, system APIs) and when testing interactions that cross boundaries between Models, Views, ViewModels, and Services. Mocks should be protocol-based and injected via dependency injection where possible.
        - Follow Apple's official Swift API Design Guidelines: https://swift.org/documentation/api-design-guidelines/
        - Manage dependencies using Swift Package Manager (SPM) whenever possible. Avoid unnecessary dependencies and prefer lightweight, well-maintained libraries.
        - Keep third-party dependencies up to date and review for security and compatibility.
        - Use semantic versioning for dependencies and document them clearly in the project.
        - Follow the Model-View-ViewModel (MVVM) architectural pattern for new code. MVC may be used for simple components, but MVVM is preferred for maintainability and testability.
        - Organize code into logical modules and use folder structure to separate concerns (e.g., Models, Views, ViewModels, Services).
        - Avoid tight coupling between components; use protocols and dependency injection where appropriate.
        - Ensure all UI code is accessible and follows Apple's Human Interface Guidelines.

## Summary
- For each implementation step:
    1. Document the design and approach in `dev-log.md` before writing tests or code.
    2. Write tests based on the documented design and the specification files.
    3. Implement the code, ensuring it passes all tests.
    4. If the code works and tests pass, add and commit the changes to git.
    5. After committing, confirm whether the changes should be synced (pushed) to GitHub.

 - Maintain an up-to-date text-based diagram (such as Mermaid or PlantUML) in `dev-log.md` to visually represent the application's architecture and design. Update the diagram as the design evolves.

---
For questions or clarifications, refer to the spec files or open an issue in the repository.

# zPod Development Guidelines

## Overview
These instructions outline the development process and standards for building the zPodcastAddict (zPod) application using Swift 6, targeting iOS 18+ and watchOS 11+ platforms exclusively.

## Project Requirements

### Target Platforms
- **Language:** Swift 6.1.2 with strict concurrency compliance
- **Platforms:** iPhone (iOS 18+), Apple Watch (watchOS 11+), and CarPlay
- **Target device:** iPhone 16 (or equivalent iOS 18 simulator)
- **Specification-Driven:** All features must follow the specification files in the `spec` directory (Given/When/Then format)

## Development Process

### Test-Driven Development (TDD)
- Always follow TDD: write failing tests first, then implement code, then refactor
- Build both unit tests and integration tests when possible
- Refactor tests and/or add integration tests if gaps are found
- Reference the spec files (Given/When/Then) and ensure code matches expectations
- Tests should follow specifications to ensure correct behavior

### Implementation Workflow
For each implementation step, follow this process explicitly:

1. **Design Documentation:**
   - Document the design and approach in `dev-log.md` before writing any tests or code
   - Maintain an up-to-date text-based diagram (Mermaid or PlantUML) in `dev-log.md`

2. **Test-Driven Development:**
   - Write tests based on documented design and Given/When/Then scenarios in spec files
   - If a scenario isn't robust enough, update the spec file first, then tests, then code

3. **Implementation:**
   - Implement code ensuring it passes all tests
   - Use ecosystem tools to automate parts of the task instead of manual changes

4. **Version Control:**
   - If code works and tests pass, add and commit changes with clear messages
   - Commits should include updates to the dev-log file for the related issue
   - After committing, confirm whether changes should be synced (pushed) to GitHub

## Swift 6 Best Practices

### Swift 6 Concurrency & Sendable
- Always use `async`/`await` for asynchronous operations instead of completion handlers
- Mark types as `Sendable` when they can be safely passed across concurrency domains
- Use `@preconcurrency import` for libraries not yet updated for Swift 6 concurrency
- Prefer `@MainActor` for UI-related classes and methods
- Use `nonisolated` for methods that don't need actor isolation
- Handle concurrency warnings and make explicit isolation decisions

### Actor Usage
- Use actors for mutable shared state that needs thread-safe access
- Prefer `@MainActor` for view models and UI controllers
- Use global actors sparingly and only when appropriate
- Design actor interfaces to minimize cross-actor calls
- Use `nonisolated` for computed properties that don't access mutable state

### Error Handling
- Use typed throws (`throws(SpecificError)`) when possible for better error handling
- Prefer Result types for complex error scenarios
- Handle errors at appropriate levels in the call stack
- Use custom error types that conform to `LocalizedError` for user-facing errors

### Memory Management
- Use `weak` references to break retain cycles in closures and delegates
- Prefer `unowned` only when certain the referenced object will outlive the current context
- Use `@escaping` closures judiciously and always consider memory implications
- Avoid creating retain cycles with async/await patterns

### Property Wrappers
- Use `@Published` for properties that should trigger UI updates
- Use custom property wrappers for common patterns (like UserDefaults storage)
- Always consider thread safety when creating custom property wrappers

### Combine Framework
- Use `@preconcurrency import Combine` until Combine is fully Swift 6 compatible
- Prefer async/await over Combine for simple async operations
- Use Combine for complex data transformation and UI binding scenarios
- Always manage subscription lifecycle properly

## Testing Best Practices

### Main Application Testing Framework

#### Test Organization and Structure
- **Specification-Based Testing**: Organize tests around specifications rather than development issues
- Map each test file to specific sections in `spec/` directory
- Use descriptive test method names that reflect specification scenarios: `testAcceptanceCriteria_CompleteNavigationFlow()`
- Organize tests with clear Given/When/Then structure using comments
- Group related tests using `// MARK:` comments for better navigation
- Include comprehensive documentation of what each test validates

#### Main App Test Categories

**Unit Tests (`zpodTests/`)**
- Test individual components and their interactions within the main application
- Focus on business logic and component behavior
- Use isolated test data and mock services
- Examples: `PlaybackControlTests`, `PlaylistManagementTests`, `ContentOrganizationTests`, `PodcastManagementTests`

**UI Tests (`zpodUITests/`)**
- Test user interface behavior and complete user workflows
- Focus on accessibility compliance and platform-specific features
- Test navigation flows, user interactions, and visual feedback
- Examples: `CoreUINavigationTests`, `PlaybackUITests`, `ContentDiscoveryUITests`

**Integration Tests (`IntegrationTests/`)**
- Test end-to-end workflows and cross-component interactions
- Focus on data consistency and component integration
- Test platform integrations (CarPlay, Apple Watch, etc.)
- Examples: `CoreWorkflowIntegrationTests`, `PlatformIntegrationTests`

#### Test Data Management
- Use separate UserDefaults suites for each test to ensure isolation
- Create fresh instances for each test to avoid state pollution
- Use consistent test fixtures and mock data across related tests
- Clean up test data after each test run

#### Async Testing Patterns
- Use `async` test methods for testing async code: `func testExample() async`
- Use `await` for all async operations in tests
- Set up and tear down async resources properly in `setUp()` and `tearDown()`
- Handle concurrency with proper isolation and synchronization

#### Combine Testing
- Use `Set<AnyCancellable>` to manage test subscriptions
- Store publishers in instance variables for proper lifecycle management
- Always call `store(in: &cancellables)` to prevent memory leaks
- Test both published properties and custom publishers

#### Mock Objects and Test Doubles
- Use mock objects when verifying behavior involving external dependencies
- Use mocks when testing interactions that cross boundaries between Models, Views, ViewModels, and Services
- Mocks should be protocol-based and injected via dependency injection where possible
- Create reusable mock implementations in test support files

#### UI Testing Best Practices
- Test accessibility compliance with VoiceOver labels and navigation
- Verify platform-specific adaptations (iPhone, iPad, CarPlay)
- Test error states and edge cases in user interfaces
- Include performance validation for UI responsiveness
- Test dark mode and appearance adaptations

#### Integration Testing Best Practices
- Test complete user workflows that span multiple components
- Verify data persistence across app sessions and component boundaries
- Test platform service integrations (notifications, background tasks, etc.)
- Validate cross-component data synchronization
- Test performance under realistic usage patterns

#### Validation Testing
- Test boundary conditions and invalid inputs
- Verify that invalid values are properly clamped or rejected
- Test both positive and negative scenarios
- Include edge cases in your test coverage
- Test error handling and recovery scenarios

#### Test Documentation Requirements
- Each test directory must include a `TestSummary.md` file
- Document which specifications each test file covers
- Explain the purpose and scope of each test category
- Map test methods to specific specification scenarios
- Include coverage analysis and gaps identification

### Package Testing vs Main App Testing

#### Package Tests
- Focus on individual package functionality in isolation
- Test public APIs and contracts between packages
- Use package-specific test utilities and fixtures
- Keep tests independent of main application concerns
- Located in `Packages/*/Tests/`

#### Main App Tests
- Focus on application-level workflows and integration
- Test how packages work together in the context of the full app
- Include UI testing and user experience validation
- Test platform-specific features and integrations
- Located in `zpodTests/`, `zpodUITests/`, and `IntegrationTests/`

#### Key Differences
- **Scope**: Package tests are narrow and focused; main app tests are broad and integrative
- **Dependencies**: Package tests minimize dependencies; main app tests include full application context
- **Platform Features**: Package tests avoid platform-specific code; main app tests embrace platform integration
- **User Workflows**: Package tests focus on API contracts; main app tests focus on user scenarios

## Swift Coding Standards

### Core Principles
- Use clear, descriptive names for variables, functions, and types
- Prefer value types (structs, enums) over reference types (classes) when possible
- Use optionals safely and avoid force-unwrapping
- Write concise, readable code with proper indentation and spacing
- Use access control (private, fileprivate, internal, public) appropriately
- Favor protocol-oriented programming and composition over inheritance
- Follow Apple's official Swift API Design Guidelines

### Documentation and Comments
- Document code with comments and use Swift's documentation syntax (///)
- Include usage examples in documentation when helpful
- Document preconditions and postconditions
- Explain complex algorithms and business logic

### API Design
- Use clear, descriptive parameter names
- Prefer methods that return values over methods that modify state
- Design APIs that are hard to misuse
- Use default parameter values to reduce API surface area
- Follow Swift naming conventions consistently

### Performance Considerations
- Use `lazy` properties for expensive computations that may not be needed
- Prefer value types (structs) over reference types (classes) when appropriate
- Use `@inlinable` for small, frequently called functions
- Consider using `@frozen` for public structs that won't change

## SwiftUI Best Practices

### State Management
- Use `@State` for local view state
- Use `@StateObject` for creating and owning observable objects
- Use `@ObservedObject` for objects owned elsewhere
- Use `@EnvironmentObject` for dependency injection
- Keep view bodies lightweight and extract complex logic into methods or computed properties

### UI Guidelines
- Ensure all UI code is accessible and follows Apple's Human Interface Guidelines

## Code Organization

### Project Structure
- Use extensions to organize code by functionality
- Keep related functionality grouped together
- Use `// MARK:` comments for clear code sections
- Prefer composition over inheritance where possible
- Organize code into logical modules and use folder structure to separate concerns
- Avoid tight coupling between components; use protocols and dependency injection

### Architectural Patterns
- Follow the Model-View-ViewModel (MVVM) architectural pattern for new code
- MVC may be used for simple components, but MVVM is preferred for maintainability and testability

## Modularization & Package Boundaries

### Package Structure
- **Standard modules:** CoreModels, FeedParsing, Networking, Persistence, SettingsDomain, PlaybackEngine, SharedUtilities, TestSupport
- **Optional feature UI modules:** LibraryFeature, SearchFeature, PlayerFeature
- **Dependency direction:** Utilities → CoreModels → (Networking, Persistence, FeedParsing) → SettingsDomain → Feature UIs → App
- **PlaybackEngine:** Used by Feature UIs/App

### Concurrency Boundaries
- Mark cross-package value types `Sendable`
- Use actors for shared mutable state
- Limit `@MainActor` to UI modules
- Define async protocols at seams
- Minimize cross-actor hops

### Access Control
- Keep public surfaces small
- Prefer `internal` by default
- Expose protocols for cross-package seams
- Document isolation and error types on public APIs

### Testing Strategy
- Each package has its own test target
- Use TestSupport for fixtures/fakes
- Prefer protocol-driven injection for Networking/Persistence

### Platform/Resources
- Keep CoreModels/Parsing platform-agnostic
- Gate AVFoundation code with `#if canImport(AVFoundation)`
- Keep SwiftUI previews in the app or a PreviewSupport target

### Migration Path (Incremental)
1. Extract CoreModels + TestSupport
2. Extract Persistence + SettingsDomain
3. Extract Networking + FeedParsing
4. Optionally extract PlaybackEngine
5. Split feature UIs later if needed

### Acceptance Criteria
- App builds and tests pass
- UI targets do not depend directly on Persistence/Networking

## Package Management

### Dependency Management
- Keep `Package.swift` dependencies up to date
- Use specific version ranges rather than branch dependencies
- Document why each dependency is needed
- Regularly audit dependencies for security and maintenance status
- Manage dependencies using Swift Package Manager (SPM) whenever possible
- Avoid unnecessary dependencies and prefer lightweight, well-maintained libraries
- Use semantic versioning for dependencies and document them clearly

## Project-Specific Guidelines

### Settings Management
- Settings should cascade from global to per-podcast overrides
- Use the SettingsManager pattern for centralized configuration
- Validate settings values and clamp to safe ranges
- Ensure settings persist across app restarts
- Use Combine publishers for UI updates and change notifications

### Migration Guidelines
- When updating from older Swift versions, address all concurrency warnings
- Test thoroughly when migrating async code
- Update test patterns to match the new concurrency model

## Development Environment

### Platform Targeting
- Build for iOS 18+ and watchOS 11+ only
- Use `.iOS(.v18)` and `.watchOS(.v11)` in manifests, scripts, and CI
- Target device for simulator runs: iPhone 16 (or equivalent iOS 18 simulator)

### Development Tools

#### macOS Development (Full xcodebuild Access)
```bash
# Check Xcode version
xcodebuild -version

# List available schemes and targets
xcodebuild -list -project zpod.xcodeproj

# Build the project (iOS Simulator)
xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator

# Run tests
xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' test

# Clean build
xcodebuild -project zpod.xcodeproj -scheme zpod clean
```

#### Non-macOS Development (Alternative Tools)
```bash
# Run all development checks (recommended)
./scripts/dev-build.sh all

# Run syntax checking only
./scripts/dev-build.sh syntax

# Show project information
./scripts/dev-build.sh info

# Show available targets and schemes
./scripts/dev-build.sh list

# Check Swift 6 concurrency patterns
./scripts/dev-build.sh concurrency

# Run development tests (syntax + concurrency)
./scripts/dev-build.sh test
```

#### Enhanced Development Script Features
- Swift 6 concurrency pattern detection
- DispatchQueue anti-pattern warnings
- Non-exhaustive catch block detection
- `@MainActor` timer usage validation
- Early warning system for compilation issues

### CI/CD Pipeline
The repository includes a GitHub Actions workflow that:
1. Runs on `macos-latest` with full Xcode access
2. Uses the latest stable Xcode version
3. Resolves Swift package dependencies
4. Builds and tests the iOS application
5. Uploads test logs and crash reports

### Development Workflow
1. **On macOS:** Use Xcode or xcodebuild commands directly
2. **On other platforms:** Use `./scripts/dev-build.sh` for syntax and concurrency checking
3. **Real-time error checking:**
   - Enhanced dev script provides Swift 6 concurrency issue detection
   - CI pipeline provides comprehensive checks with every push
   - Local syntax checking available via development script
   - VS Code extensions can provide additional Swift language support

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
- SwiftUI, SwiftData, and Combine are not available on non-Apple platforms
- Full compilation and testing require macOS with Xcode
- The `Package.swift` is experimental and excludes iOS-specific frameworks
- AVFoundation and other Apple frameworks are iOS/macOS only

## Logging and Documentation

### Development Logging
- For each issue, create a new dev-log in the `dev-log` directory
- Create and update a dev-log for each issue you are working on
- Continuously update the dev-log file: write approach before code changes, then record progress
- Document approach in bullet format with phases; update progress on each phase
- Keep a log of changes with date and time stamps (Eastern Time)

### Application Logging
- Use best practices of Swift 6/iOS for logging of errors, warnings, and issues
- Use `OSLog` for application logging

### Build Results
- For each build/test, create a file containing raw test and build results
- Name log files `TestResults_<timestamp>_<what-you-tested>.log`
- Put them in the `TestResults` subdirectory
- Keep only the latest 3 build/test result files for any set of tests

### Git Commits
- For each set of updates, create git commits
- Commits should include updates to the dev-log file for the related issue
- After finishing changes for an issue, push the changes to GitHub

---

For questions or clarifications, refer to the spec files or open an issue in the repository.
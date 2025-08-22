# Swift 6 Best Practices for zPod

## Swift 6 Concurrency & Sendable

- Always use `async`/`await` for asynchronous operations instead of completion handlers
- Mark types as `Sendable` when they can be safely passed across concurrency domains
- Use `@preconcurrency import` for libraries not yet updated for Swift 6 concurrency
- Prefer `@MainActor` for UI-related classes and methods
- Use `nonisolated` keyword for methods that don't need actor isolation
- Always handle potential concurrency warnings and make explicit isolation decisions

## Actor Usage

- Use actors for mutable shared state that needs thread-safe access
- Prefer `@MainActor` for view models and UI controllers
- Use global actors sparingly and only when appropriate
- Design actor interfaces to minimize cross-actor calls
- Use `nonisolated` for computed properties that don't access mutable state

## Error Handling

- Use typed throws (`throws(SpecificError)`) when possible for better error handling
- Prefer Result types for complex error scenarios
- Always handle errors at appropriate levels in the call stack
- Use custom error types that conform to `LocalizedError` for user-facing errors

## Testing Best Practices

### Test Structure and Organization
- Use descriptive test method names that explain the scenario: `testAcceptanceCriteria1_CascadingResolution()`
- Organize tests with clear Given/When/Then structure using comments
- Group related tests using `// MARK:` comments for better navigation
- Use separate UserDefaults suites for each test to ensure isolation

### Async Testing Patterns
- Always use `async` test methods for testing async code: `func testExample() async`
- Use `await` for all async operations in tests
- Set up and tear down async resources properly in `setUp()` and `tearDown()`

### Combine Testing
- Use `Set<AnyCancellable>` to manage test subscriptions
- Store publishers in instance variables for proper lifecycle management
- Always call `store(in: &cancellables)` to prevent memory leaks
- Test both published properties and custom publishers

### Test Data Management
- Use unique UserDefaults suite names per test: `UserDefaults(suiteName: "test-criteria-1")`
- Always clean up test data: `userDefaults.removePersistentDomain(forName: "test-criteria-1")`
- Create fresh instances for each test to avoid state pollution

### Validation Testing
- Test boundary conditions and invalid inputs
- Verify that invalid values are properly clamped or rejected
- Test both positive and negative scenarios
- Include edge cases in your test coverage

### Integration Testing
- Test end-to-end scenarios that mirror real user workflows
- Verify that settings persist across app restarts
- Test cascading behavior (global → per-podcast overrides)
- Validate backward compatibility with existing APIs

## Memory Management

- Use `weak` references to break retain cycles in closures and delegates
- Prefer `unowned` only when you're certain the referenced object will outlive the current context
- Use `@escaping` closures judiciously and always consider memory implications
- Avoid creating retain cycles with async/await patterns

## SwiftUI Best Practices

- Use `@State` for local view state
- Use `@StateObject` for creating and owning observable objects
- Use `@ObservedObject` for objects owned elsewhere
- Use `@EnvironmentObject` for dependency injection
- Keep view bodies lightweight and extract complex logic into methods or computed properties

## Code Organization

- Use extensions to organize code by functionality
- Keep related functionality grouped together
- Use `// MARK:` comments for clear code sections
- Prefer composition over inheritance where possible

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

- Use `@Published` for properties that should trigger UI updates
- Use custom property wrappers for common patterns (like UserDefaults storage)
- Always consider thread safety when creating custom property wrappers

## Combine Framework

- Use `@preconcurrency import Combine` until Combine is fully Swift 6 compatible
- Prefer async/await over Combine for simple async operations
- Use Combine for complex data transformation and UI binding scenarios
- Always manage subscription lifecycle properly

## Performance Considerations

- Use `lazy` properties for expensive computations that may not be needed
- Prefer value types (structs) over reference types (classes) when appropriate
- Use `@inlinable` for small, frequently-called functions
- Consider using `@frozen` for public structs that won't change

## API Design

- Use clear, descriptive parameter names
- Prefer methods that return values over methods that modify state
- Design APIs that are hard to misuse
- Use default parameter values to reduce API surface area
- Follow Swift naming conventions consistently

## Documentation

- Use documentation comments (`///`) for public APIs
- Include usage examples in documentation when helpful
- Document preconditions and postconditions
- Explain complex algorithms and business logic

## Package Management

- Keep Package.swift dependencies up to date
- Use specific version ranges rather than branch dependencies
- Document why each dependency is needed
- Regularly audit dependencies for security and maintenance status

## Migration Guidelines

- When updating from older Swift versions, address all concurrency warnings
- Test thoroughly when migrating async code
- Update test patterns to match new concurrency model

## Project-Specific Guidelines

- Settings should cascade from global to per-podcast overrides
- Use the SettingsManager pattern for centralized configuration
- Always validate settings values and clamp to safe ranges
- Ensure settings persist across app restarts
- Use Combine publishers for UI updates and change notifications

## Logging all updates

- for each issue, create a new dev-log in the dev-log file in the root of this repository 
- create and then update a  dev-log for each issue you are working on.
- continuously update the dev-log file that was created for each issue
- before making any updates, make sure to update the dev-log file first with your approach and then as you make progress, go back to update the progress.
- document your approach for implementing the issue in bullet format with as many phases as you need and then update where you are in that implemenation
- keep a log of the changes, include date and time for when those changes were made
- when doing the updates in the log, make sure to use date and time stamps, with the timestamps based on Eastern Time

## Git commits

- for each set of updates, do git commits
- these commits should happen in conjunction iwth the dev-log for the issue you are working on
- the commits should include the updates to the dev-log file
- after you are done making changes for the issue, push the changes to github
- 

## logging in application
- use best practices of Swift 6.0/ios for logging of errors, warnings, issues, etc. 
- use OSLog for this logging approach 

## Build Results
- for each build/test - create a file for test and build results. 
- when creating the log files for tests and build results, call them TestResults with a date/time stamp. 
- put them in the sub directory TestResults
- Keep only the latest 30 builds/test results

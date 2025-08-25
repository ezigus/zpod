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
- Reference: See `dev.log/dev-log.issue11.5-refactor.log` for details and checklist.

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
- Gradually adopt Swift 6 features rather than wholesale rewrites
- Test thoroughly when migrating async code
- Update test patterns to match new concurrency model

## Project-Specific Guidelines

- Settings should cascade from global to per-podcast overrides
- Use the SettingsManager pattern for centralized configuration
- Always validate settings values and clamp to safe ranges
- Ensure settings persist across app restarts
- Use Combine publishers for UI updates and change notifications

# Development Instructions for zPodcastAddict

<!--This portion of the file is coming from a different copilot-instructions.md file. I am combining these two files together. These two files are going to need to be recongciled with updates to reflect one comprehensive set of instructions
-->

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

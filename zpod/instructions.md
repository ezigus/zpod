# Development Instructions for zPod

<!--
USAGE NOTES FOR THIS FILE:

This file contains the main development instructions for the zPod project. To ensure these instructions are used by GitHub Copilot and other agents, a symbolic link is created from `.github/copilot-instructions.md` in the root of the workspace to this file. This allows Copilot and other tools to automatically reference the latest instructions.

To set up the symlink, run the following command from the root of your workspace:

    ln -s zpod/instructions.md .github/copilot-instructions.md

This ensures that any updates to `instructions.md` are immediately reflected in `.github/copilot-instructions.md`.

When updating instructions, always edit `zpod/instructions.md` directly. The symlink will keep `.github/copilot-instructions.md` up to date for Copilot and other agents.

For best results, keep this file concise, clear, and focused on actionable standards and processes for the project.
-->

## Overview
These instructions outline the development process and standards for building the zPod application.

## Requirements
1. **Language:** All code must be written in Swift 6 with strict concurrency enabled.
2. **Target Platforms:** The application is to be built exclusively for iPhone (iOS), Apple Watch (watchOS), and CarPlay.
3. **Target Devices:** Primary testing and optimization should focus on iPhone 15 and iPhone 16 models, while maintaining backward compatibility with earlier iPhone models.
4. **Specification-Driven:** All features and functionality must follow the specification files found in the `spec` directory. Specifications are written in Given/When/Then format.

## Development Process
For each implementation step, the following process must be followed explicitly:
1. **Design Documentation:**
   - Document the design and approach for the step in the appropriate issue-specific log file in `dev.log/dev-log.issue[##].log` before writing any tests or code.
   - For general project setup or foundation work, use `dev.log/dev-log.foundation.log`.
   - The main `dev.log/dev-log.md` serves as an index to all issue-specific logs.
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

### Ordering & Traceability Enforcement
Before beginning work on any issue, the assistant (and contributors) MUST:
1. Consult `spec/issues-review.md` to verify the issue's recommended wave and dependencies.
2. Confirm all prerequisite issues (dependencies) are either completed or explicitly stubbed with agreed design notes in the appropriate issue-specific log file.
3. Reference the issue number and its wave in the new issue-specific log file entry header (e.g., `Wave 1 | Issue 03-Playback Engine`), and list any dependency verifications performed.
4. If an out-of-order implementation is intentionally chosen, append a justification paragraph in the relevant issue log file titled `Ordering Deviation` explaining risk mitigation and planned reconciliation steps.
5. Abort or pause implementation if `issues-review.md` indicates pending architectural adjustments affecting the target feature until the document is updated.

Any pull request or commit lacking a clear link back to its issue number and wave (as defined in `issues-review.md`) should be considered incomplete and not pushed until corrected.

## SWIFT Coding Standards

    - All code must follow Swift 6 best practices and conventions with strict concurrency enabled. Key standards include:
        - Use clear, descriptive names for variables, functions, and types.
        - Prefer value types (structs, enums) over reference types (classes) when possible.
        - Use optionals safely and avoid force-unwrapping.
        - Write concise, readable code with proper indentation and spacing.
        - Use access control (private, fileprivate, internal, public) appropriately.
        - Favor protocol-oriented programming and composition over inheritance.
        - Document code with comments and use Swift's documentation syntax (///).
        - Avoid using magic numbers or strings; use constants and enums.
        - Handle errors gracefully using Swift's error handling mechanisms (try/catch, Result type).
        - Properly handle Swift 6 concurrency with @MainActor, async/await, and Sendable protocols where appropriate.
        - Use actor isolation correctly to prevent data races and ensure thread safety.
        - Write unit tests for all logic and maintain high test coverage.
        - Use mock objects in tests when verifying behavior involving external dependencies (e.g., network, storage, system APIs) and when testing interactions that cross boundaries between Models, Views, ViewModels, and Services. Mocks should be protocol-based and injected via dependency injection where possible.
        
### Swift 6 Testing Best Practices
        - **NO @MainActor on test methods**: Avoid using @MainActor annotations on test methods as this forces test methods into main actor isolation, which is not the correct Swift 6 approach.
        - **Use async/await for actor-isolated calls**: Test methods should be declared as `async` and use `await` when calling main actor-isolated methods or initializers. This maintains proper actor safety while keeping tests readable.
        - **Maintain actor safety**: Let Swift's concurrency system handle actor isolation boundaries through async/await rather than forcing test methods into specific actor contexts.
        - **Clean and readable**: Test code should be explicit about when it's crossing actor boundaries, making the concurrency behavior clear and maintainable.
        - **Prefer lazy properties for actor-isolated test dependencies**: Use lazy properties with actor isolation (`@MainActor private lazy var`) for test dependencies that require main actor isolation, allowing them to be initialized on first access from async test methods.
        
        - Follow Apple's official Swift API Design Guidelines: https://swift.org/documentation/api-design-guidelines/
        - Manage dependencies using Swift Package Manager (SPM) whenever possible. Avoid unnecessary dependencies and prefer lightweight, well-maintained libraries.
        - Keep third-party dependencies up to date and review for security and compatibility.
        - Use semantic versioning for dependencies and document them clearly in the project.
        - Follow the Model-View-ViewModel (MVVM) architectural pattern for new code. MVC may be used for simple components, but MVVM is preferred for maintainability and testability.
        - Organize code into logical modules and use folder structure to separate concerns (e.g., Models, Views, ViewModels, Services).
        - Avoid tight coupling between components; use protocols and dependency injection where appropriate.
        - Ensure all UI code is accessible and follows Apple's Human Interface Guidelines.
        - Optimize performance and user experience for iPhone 15 and iPhone 16 capabilities while maintaining compatibility with older devices.

## Summary
- For each implementation step:
    1. Document the design and approach in the appropriate issue-specific log file (`dev.log/dev-log.issue[##].log`) before writing tests or code.
    2. Write tests based on the documented design and the specification files.
    3. Implement the code, ensuring it passes all tests with Swift 6 strict concurrency compliance.
    4. If the code works and tests pass, add and commit the changes to git.
    5. After committing, confirm whether the changes should be synced (pushed) to GitHub.

- Maintain an up-to-date text-based diagram (such as Mermaid or PlantUML) in the relevant issue-specific log files to visually represent the application's architecture and design. Update the diagrams as the design evolves.
- Use `dev.log/dev-log.md` as the main index to navigate between issue-specific development logs.
- For general project setup work, use `dev.log/dev-log.foundation.log`.

---
For questions or clarifications, refer to the spec files or open an issue in the repository.

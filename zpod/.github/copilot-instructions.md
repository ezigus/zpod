# Development Instructions for zPodcastAddict

<!--
USAGE NOTES FOR THIS FILE:

This file contains the main development instructions for the zPodcastAddict project. To ensure these instructions are used by GitHub Copilot and other agents, a symbolic link is created from `.github/copilot-instructions.md` in the root of the workspace to this file. This allows Copilot and other tools to automatically reference the latest instructions.

To set up the symlink, run the following command from the root of your workspace:

    ln -s zpodcastaddict/instructions.md .github/copilot-instructions.md

This ensures that any updates to `instructions.md` are immediately reflected in `.github/copilot-instructions.md`.

When updating instructions, always edit `zpodcastaddict/instructions.md` directly. The symlink will keep `.github/copilot-instructions.md` up to date for Copilot and other agents.

For best results, keep this file concise, clear, and focused on actionable standards and processes for the project.
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

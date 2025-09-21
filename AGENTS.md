# zPod Development Guidelines

## 1. Targets & Scope
- **Language**: Swift 6.1.2 with strict concurrency compliance.
- **Platforms**: iPhone (iOS 18+), watchOS 11+, CarPlay. Build UI for iPhone only.
- **Reference Specs**: All features must trace to `spec/` Given/When/Then scenarios.
- **Primary device**: iPhone 16 simulator (iOS 18.0 or newer).

## 2. Workflow Expectations
1. **Design first** – document intent and Mermaid/PlantUML diagrams in the relevant `dev-log/*.md` before writing tests or code.
2. **TDD always** – add or update specs if the scenario is incomplete, write failing tests, implement, then refactor.
3. **Automation over manual edits** – use scripts, generators, and formatters whenever possible.
4. **Version control hygiene** – commit only after tests pass, include matching dev-log updates, then confirm whether to push.

## 3. Concurrency & Swift Patterns
- Prefer `async`/`await`; avoid completion handlers unless required.
- Annotate cross-actor types with `Sendable`; mark UI-facing APIs `@MainActor` and explicitly drop isolation with `nonisolated` only when safe.
- Never change actor isolation on overrides (e.g. `XCTestCase.setUpWithError()` stays nonisolated).
- Avoid capturing `self` across actors; copy values locally.
- Validate APIs before use—confirm enum cases, signatures, and optionality.
- Compile frequently to catch isolation warnings early.

### UI / XCUI Testing Concurrency Rules
- Keep `setUpWithError()`/`tearDownWithError()` nonisolated; launch apps inside `@MainActor` helpers per test.
- Store `XCUIApplication` in `nonisolated(unsafe)` properties only after local initialization.
- **Never** block the main thread with semaphores or `sleep`; use helper waiters (`waitForAnyElement`, `navigateAndWaitForResult`, `waitForContentToLoad`).
- UI loading remains asynchronous—show indicators, and wait for state changes instead of fixed timeouts.

## 4. Testing Strategy
### Test Types & Locations
| Type | Purpose | Location |
| --- | --- | --- |
| Unit | Component logic, models, services | `zpodTests/` |
| UI | End-to-end user flows, accessibility | `zpodUITests/` |
| Integration | Cross-module workflows, platform services | `IntegrationTests/` |
| Package | Module-specific APIs | `Packages/*/Tests/` |

### General Expectations
- Map every test to a spec scenario; mirror Given/When/Then in comments or structure.
- Keep fixtures isolated (`UserDefaults` suites, fresh instances per test) and clean up afterwards.
- Use async test functions and `await` for asynchronous work; respect actor isolation in mocks (mark as `@unchecked Sendable` and guard with locks when needed).
- Before writing UI assertions, ensure accessibility identifiers/labels exist; prefer discovery helpers over index-based lookups.
- Maintain `TestSummary.md` in each test directory documenting coverage and gaps.

### API Verification Checklist
1. Inspect implementation files for exact method, property, and enum definitions.
2. Confirm isolation annotations (`@MainActor`, `Sendable`).
3. Compile early; fix similar mismatches across the codebase, not just the first failure.

## 5. Coding Standards
- Follow Swift API Design Guidelines; choose descriptive names and avoid force unwraps.
- Favor value types; limit class usage to reference semantics.
- Apply access control intentionally (default to `internal`).
- Document complex logic with `///` comments and include usage notes when helpful.
- In SwiftUI, keep state minimal (`@State`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject` as appropriate) and ensure accessibility compliance.

## 6. Architecture & Modularization
- Preferred presentation pattern: MVVM (MVC permitted only for small components).
- Organize source with `// MARK:` regions and extensions grouped by responsibility; avoid tight coupling—depend on protocols/DI.
- Package structure: `SharedUtilities → CoreModels → (Networking | Persistence | FeedParsing) → SettingsDomain → Feature UIs (Library, Search, Player, Playlist) → App`. `PlaybackEngine` supports feature UIs and the app.
- Mark cross-package value types `Sendable`; limit `@MainActor` to UI modules; keep platform-specific resources out of lower layers.
- Modularization path: extract CoreModels/TestSupport first, then Persistence/SettingsDomain, Networking/FeedParsing, optionally PlaybackEngine, and finally feature UIs.

## 7. Tooling & CI
### macOS (Full Xcode)
Use the shared helper script for a quick local verification:

```bash
./scripts/run-xcode-tests.sh --self-check
./scripts/run-xcode-tests.sh full_build_and_test
```

Legacy xcodebuild commands remain available if you need manual control:

```bash
xcodebuild -version
xcodebuild -list -project zpod.xcodeproj
xcodebuild -project zpod.xcodeproj -scheme zpod -sdk iphonesimulator
xcodebuild -project zpod.xcodeproj -scheme zpod \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0' test
xcodebuild -project zpod.xcodeproj -scheme zpod clean
```

### Non-macOS / Lightweight Environments
Use `scripts/dev-build.sh` (`all`, `syntax`, `list`, `concurrency`, `test`) or the enhanced script variants (`scripts/dev-build-enhanced.sh syntax|swiftui|concurrency|test`). These scripts provide early warnings for SwiftUI type conflicts, concurrency violations, and syntax errors. When Xcode isn’t available, `./scripts/run-xcode-tests.sh --self-check` validates tooling expectations and falls back to SwiftPM.

### CI Pipeline
GitHub Actions (`.github/workflows/ci.yml`) now:
1. Select Xcode 16.4 and perform `./scripts/run-xcode-tests.sh --self-check`.
2. Ensure a suitable iOS simulator runtime exists (iPhone 16 preferred) and create a device when possible.
3. Invoke `./scripts/run-xcode-tests.sh full_build_and_test` for the macOS leg.
4. Run `./scripts/run-xcode-tests.sh --self-check` and `./scripts/dev-build-enhanced.sh syntax` on Ubuntu to exercise the SwiftPM fallback path.
5. Archive crash logs and test reports.

### Known Limitations
- Full builds/tests require macOS with Xcode.
- SwiftUI/SwiftData/Combine are unavailable off Apple platforms; `Package.swift` remains experimental and omits iOS-only frameworks.

## 8. Issue & Documentation Management
- Create issues in `Issues/` when work falls outside an existing scope; name files `xx.y-description.md` to preserve ordering. Use sub-issue numbering (e.g. `17.1`) when inserting between existing IDs.
- Issue files must include description, acceptance criteria, spec references, dependencies, and testing strategy.
- Add TODO comments as `// TODO: [Issue #xx.y] Description`; remove them once the issue is resolved and update the issue accordingly.

### Dev Logs & Artifacts
- Maintain individual `dev-log/*.md` entries per issue; update with intent, progress, and timestamps (ET) as work evolves.
- Store raw build/test outputs in `TestResults/TestResults_<timestamp>_<context>.log` (keep only the three most recent per test set).
- Use `OSLog` for runtime logging inside the app.

---
When in doubt, consult the relevant spec or open a follow-up issue for clarification.

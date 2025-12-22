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
   - PR titles linked to issues must include the issue identifier (e.g. `[#02.5] Testing cleanup fixes`) so GitHub references stay traceable.
   - When working on a PR, use the PR's branch exactly as created (do not rename or fork ad-hoc branches); all commits destined for that PR must land on its branch name.

### Terminal Command Guidelines

**CRITICAL: Follow these rules when executing terminal commands:**

- **NEVER** use `2>&1` redirection - it causes output buffering and user prompts
- **NEVER** run commands with `isBackground: true` - always run synchronously
- **NEVER** use `timeout`, `sleep`, or other blocking commands that prompt user interaction
- **DO** run commands directly and let them complete naturally
- **DO** use simple, clean command invocations without complex shell redirections
- **DO** trust that output will appear when the command completes

Examples:

```bash
# ✅ CORRECT - simple, direct command
./scripts/run-xcode-tests.sh -t zpodUITests/SomeTest

# ❌ WRONG - background execution
./scripts/run-xcode-tests.sh -t Test &

# ❌ WRONG - output redirection
./scripts/run-xcode-tests.sh 2>&1 | grep something

# ❌ WRONG - timeout/sleep
timeout 60 ./scripts/run-xcode-tests.sh
sleep 30 && ./scripts/run-xcode-tests.sh
```

## 3. Concurrency & Swift Patterns

- Prefer `async`/`await`; avoid completion handlers unless required.
- Annotate cross-actor types with `Sendable`; mark UI-facing APIs `@MainActor` and explicitly drop isolation with `nonisolated` only when safe.
- Never change actor isolation on overrides (e.g. `XCTestCase.setUpWithError()` stays nonisolated).
- Avoid capturing `self` across actors; copy values locally.
- Validate APIs before use—confirm enum cases, signatures, and optionality.
- Compile frequently to catch isolation warnings early.
- Persistence notifications must flow through the `SettingsRepository.settingsChangeStream()` async stream; materialize the stream from the owning actor, consume it from detached tasks, and prefer `MainActor.run {}` for UI-facing updates—do **not** resurrect Combine publishers or access repository actors directly from main-actor tasks.

### UI / XCUI Testing Concurrency Rules

- Keep `setUpWithError()`/`tearDownWithError()` nonisolated; launch apps inside `@MainActor` helpers per test.
- Store `XCUIApplication` in `nonisolated(unsafe)` properties only after local initialization.
- **Never** block the main thread with semaphores or `sleep`; use helper waiters (`waitForAnyElement`, `navigateAndWaitForResult`, `waitForContentToLoad`).
- UI loading remains asynchronous—show indicators, and wait for state changes instead of fixed timeouts.

### iOS UI Testing Best Practices

**⚠️ IMPORTANT: Review these comprehensive testing resources before building or updating UI tests:**

#### Testing Documentation

- **[Accessibility Testing Best Practices](docs/testing/ACCESSIBILITY_TESTING_BEST_PRACTICES.md)** - SwiftUI List row discovery, accessibility identifiers, UIKit fallback patterns
- **[UI Testing Advanced Patterns](docs/testing/UI_TESTING_ADVANCED_PATTERNS.md)** - Advanced XCUITest patterns, waiting strategies, element queries

#### Core Principles (FIRST)

- **Fast**: Tests should run quickly; prefer `firstMatch` over `element` when multiple matches exist
- **Independent**: Tests shouldn't share state; reset app state between tests
- **Repeatable**: Same results every time; avoid time-dependent assertions
- **Self-validating**: Automated pass/fail, not manual log interpretation
- **Timely**: Write tests before or alongside production code (TDD)

#### Waiting & Synchronization

- **Prefer `waitForExistence(timeout:)`** over `exists` checks for reliability
- **Use XCTestExpectation** for async operations with callbacks
- **Avoid fixed `sleep()` calls** except as last resort for SwiftUI timing issues
- **Set appropriate timeouts**: 1-2s for simple UI updates, 5-10s for network operations
- **Leverage predicates**: Use `XCTNSPredicateExpectation` for complex state changes

#### Element Discovery

- **Use accessibility identifiers** for reliable element targeting: `view.accessibilityIdentifier = "uniqueID"`
- **Always use `.matching(identifier:).firstMatch`** pattern: `app.buttons.matching(identifier: "Login").firstMatch` avoids duplicate identifier crashes from SwiftUI wrapper views
- **Never use subscript syntax** (`app.buttons["ID"]`) – it fails when SwiftUI generates duplicate identifiers
- **Use `children(matching:)` for direct subviews**, `descendants(matching:)` for nested elements
- **Query hierarchy efficiently**: More specific queries = better performance

#### Test Reliability

- **Disable animations** in test builds: `UIView.setAnimationsEnabled(false)`
- **Set `continueAfterFailure = false`** to stop on first failure
- **Handle system interrupts**: Use `addUIInterruptionMonitor` for permissions/alerts
- **Mock network layers** to avoid flaky tests from external dependencies
- **Use launch arguments** to configure test-specific app state

#### SwiftUI-Specific Considerations

- SwiftUI updates UI asynchronously on the main thread
- XCUITest queries execute immediately after interactions
- **SwiftUI List lazy-loading**: Both sections AND rows within sections materialize only when positioned early (~812pt viewport) – scrolling cannot materialize non-existent sections
- **Fix: structural reordering, not scrolling** – when tests can't find elements, reposition them early in the List hierarchy, don't add scrolling workarounds
- Ensure SwiftUI views have proper accessibility modifiers

**⚠️ CRITICAL: SwiftUI Lazy Unmaterialization - Always Scroll Before Interaction**

**The Problem**: SwiftUI Lists use lazy rendering—elements are removed from the accessibility tree when scrolled out of view, **even if they were previously materialized**. Pre-materialization (scrolling through all sections on sheet open) does NOT keep elements accessible after scrolling away.

**The Failure Pattern**:
```
❌ BAD: Pre-materialize all sections, scroll to top, then try to interact with bottom elements
1. Scroll to bottom (materializes all elements)
2. Scroll back to top (unmaterializes bottom elements)
3. Try to tap bottom element → Test fails (element doesn't exist)

✅ GOOD: Scroll to target element immediately before interaction
1. (Optional) Pre-materialize for performance
2. When you need to interact with element:
   a. Scroll directly to that element (ensureVisibleInSheet/ScrollViewReader)
   b. Interact immediately (tap/verify)
3. Success: Element is guaranteed visible and materialized
```

**Rule**: Never assume an element stays materialized after scrolling away. Always use `ensureVisibleInSheet` or `ScrollViewReader.scrollTo()` immediately before element interaction.

**Example**: See `SwipePresetSelectionTests` and `docs/testing/preventing-flakiness.md` for reference implementations.

**See Also**: Issue dev-log for SwipePresetSelection CI failures - Download/Organization presets unmaterialized after scroll-to-top.

#### Key Resources (re-read when updating UI tests)

1. **Hacking with Swift XCUITest Cheat Sheet**: <https://www.hackingwithswift.com/articles/148/xcode-ui-testing-cheat-sheet>
   - Quick reference for element discovery, interactions, assertions
   - Covers `waitForExistence`, `firstMatch`, query patterns
2. **Apple XCTest Documentation**: <https://developer.apple.com/documentation/xctest/user_interface_tests>
   - Official guidance on UI testing architecture
   - Asynchronous testing patterns: <https://developer.apple.com/documentation/xctest/asynchronous_tests_and_expectations>
3. **Vadim Bulavin - Testing Async Code**: <https://www.vadimbulavin.com/unit-testing-async-code-in-swift/>
   - Mocking patterns, XCTestExpectation usage, busy assertion patterns
   - Integration vs unit testing strategies
4. **Kodeco (Ray Wenderlich) UI Testing Tutorial**: <https://www.raywenderlich.com/960290-ios-ui-testing-tutorial>
   - Comprehensive tutorial covering test setup, element interaction, assertions
   - Best practices for maintainable test suites

**Advanced Patterns**: See `UI_TESTING_ADVANCED_PATTERNS.md` for community best practices beyond Apple's docs (Screen Object/Robot patterns, visibility verification, complex gestures, system alert handling, debugging techniques).

## 4. Testing Strategy

### Test Types & Locations

| Type | Purpose | Location |
| --- | --- | --- |
| Unit | App smoke validation & module re-export checks | `AppSmokeTests/` |
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

### Debug & Test Infrastructure Patterns

**When Standard UI Testing Isn't Sufficient:**

For complex UI flows where direct interaction is unreliable or tests need to bypass multi-step navigation, use the **debug overlay pattern** with environment-gated hooks:

**Pattern: Notification-Based Debug Hooks**

```swift
// 1. App code: Always-present hook (zero cost when unlistened)
extension Notification.Name {
  static let appDidInitialize = Notification.Name("AppFeature.DidInitialize")
}

// In app initialization
NotificationCenter.default.post(name: .appDidInitialize, object: nil)

// 2. Test infrastructure: Conditional listener
@MainActor
public final class DebugOverlayManager {
  private var observer: NSObjectProtocol?
  
  init() {
    if ProcessInfo.processInfo.environment["UITEST_DEBUG_MODE"] == "1" {
      observer = NotificationCenter.default.addObserver(
        forName: .appDidInitialize,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.showDebugControls()
        }
      }
    }
  }
}

// 3. UIWindow-based overlay for XCUITest accessibility
let window = UIWindow(windowScene: scene)
window.windowLevel = .alert + 100  // Above sheets/modals
window.frame = scene.screen.bounds
window.backgroundColor = .clear
window.makeKeyAndVisible()
// Immediately resign key so main window stays interactive
```

**Key Principles:**

- Hook **always present** in app code (loose coupling, zero cost when unlistened)
- Listener **conditionally attached** via runtime check (e.g., `UITEST_DEBUG_MODE=1`)
- Use `UIWindow` at high level (`.alert + 100`) for accessibility above sheets/modals
- **Never** use `#if canImport()` guards for hooks—causes CI/local parity issues
- Set environment flag in test `launchEnvironment`, not compile flags
- Properly remove observers in `deinit` to avoid leaks

**Example Use Cases:**

- Applying test presets to bypass multi-screen configuration flows
- Exposing internal state for verification without production debug UI
- Triggering specific app states for screenshot/accessibility testing
- Providing quick access to test configurations during UI test execution

**Related Documentation:**

- See `dev-log/02.6.3-swipe-configuration-test-decomposition.md` (section "2025-11-15 — Debug Overlay Accessibility") for full implementation case study
- See `Packages/LibraryFeature/Sources/LibraryFeature/SwipeDebugOverlayManager.swift` for reference implementation

## 5. Coding Standards

- Follow Swift API Design Guidelines; choose descriptive names and avoid force unwraps.
- Favor value types; limit class usage to reference semantics.
- Apply access control intentionally (default to `internal`).
- Document complex logic with `///` comments and include usage notes when helpful.
- In SwiftUI, keep state minimal (`@State`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject` as appropriate) and ensure accessibility compliance.

### SwiftUI Accessibility Identifier Best Practices

**CRITICAL**: SwiftUI automatically adds wrapper views (usually `Other`) that inherit the same accessibility identifier as their children. Duplicates are unavoidable regardless of where the identifier is attached, so the test suite—not the app code—must de-duplicate.

- Keep identifiers on the element that best conveys semantics (Text, Label, NavigationLink label, etc.) and use the lightweight UIViewRepresentable fallback in `docs/testing/ACCESSIBILITY_TESTING_BEST_PRACTICES.md` when SwiftUI hides modifiers.
- **Always** locate elements via `.matching(identifier:).firstMatch` and verify with `waitForExistence(timeout:)`. Do **not** rely on `app.buttons["ID"]`.
- Provide a descriptive identifier per element (`"Library.Tab"`, `"SwipeActions.Save"`); avoid dynamic timestamp-based names.

```swift
Button { action() } label: {
  Label("Play", systemImage: "play.fill")
    .accessibilityIdentifier("Player.PlayButton")
}

let playButton = app.buttons
  .matching(identifier: "Player.PlayButton")
  .firstMatch
XCTAssertTrue(playButton.waitForExistence(timeout: 5))
playButton.tap()
```

**Rule**: Developer code focuses on setting accurate identifiers; UI tests absorb the duplication by always using `.firstMatch`.

## 6. Architecture & Modularization

- Preferred presentation pattern: MVVM (MVC permitted only for small components).
- Organize source with `// MARK:` regions and extensions grouped by responsibility; avoid tight coupling—depend on protocols/DI.
- Package structure: `SharedUtilities → CoreModels → (Networking | Persistence | FeedParsing) → SettingsDomain → Feature UIs (Library, Search, Player, Playlist) → App`. `PlaybackEngine` supports feature UIs and the app.
- Mark cross-package value types `Sendable`; limit `@MainActor` to UI modules; keep platform-specific resources out of lower layers.
- Modularization path: extract CoreModels/TestSupport first, then Persistence/SettingsDomain, Networking/FeedParsing, optionally PlaybackEngine, and finally feature UIs.

## 7. Tooling & CI

### macOS (Full Xcode)

Never run the xcode-build on its own, always use the run-xcode-tests.sh script.
Use the shared helper script for a quick local verification:

```bash
./scripts/run-xcode-tests.sh --self-check                        # environment sanity checks
./scripts/run-xcode-tests.sh                                     # default: syntax gate → AppSmoke gate → full regression
./scripts/run-xcode-tests.sh -s                                  # syntax verification only
./scripts/run-xcode-tests.sh -b zpod                             # build without executing tests
./scripts/run-xcode-tests.sh -t zpod,zpodUITests                 # targeted test execution
./scripts/run-xcode-tests.sh -c -b zpod -t zpod                  # clean build + scheme tests
./scripts/run-xcode-tests.sh -p [suite]                          # verify test plan coverage (omit suite for default)
```

> ⚠️  Avoid running raw `xcodebuild` commands for routine work—the helper script configures destinations, result bundles, and fallbacks automatically. Only reach for direct `xcodebuild` invocations when debugging tooling issues, and mirror the flags shown by `run-xcode-tests.sh`.

**Simulator / DerivedData overrides**

- `ZPOD_SIMULATOR_UDID` (optional): forces the harness to target a specific CoreSimulator device. The script validates availability via `simctl list devices` before emitting `-destination platform=iOS Simulator,id=<udid>`.
- `ZPOD_DERIVED_DATA_PATH` (optional): when set, the harness creates the folder and forwards `-derivedDataPath` to each `xcodebuild` invocation—ideal for isolating suites in CI.
- CI sets both automatically; local developers can opt-in when needing deterministic devices or sandboxed DerivedData.

- `-b all` runs the zpod workspace build and then walks each package with SwiftPM when the host platform is supported; iOS-only packages are skipped with a warning because they already compile via the workspace scheme.
- Package modules can be exercised directly (`-t SharedUtilities`, `-t SharedUtilitiesTests`) and fall back to `swift test` under the hood.
- Full regression (`-t zpod`) targets the `"zpod (zpod project)"` scheme, which runs unit + UI suites; SwiftPM-only test targets remain covered via their individual `swift test` runs.
- Running `./scripts/run-xcode-tests.sh` with no arguments now performs the full suite in gated order: syntax check first, AppSmokeTests second, then test-plan coverage, workspace build, all SwiftPM package tests, integration + UI suites, and Swift lint. Syntax or AppSmoke failures stop the remaining phases immediately so follow-ups always start from a healthy base.
- running with -t and the class you want to test will test that specific test class and nothing more.
- When possible, after each modification made, rerun a very targeted test that will show that the code that was modified works correctly. Once those tests pass 100%, commit those changes locally.  Then complete the full regression test using the default ./scripts/run-xcode-tests.sh without any flags and only then, push the changes to github.

### Non-macOS / Lightweight Environments

Prefer `./scripts/run-xcode-tests.sh -s` for syntax and `-t`/`-b` combinations for package tests even on Linux.

### CI Pipeline

as you build code, be aware that you need to be able to run in a CI pipeline in github. this means that the tests do not persist between tests and data will not be saved, so tests need to be self supporting when they are run, which means if tests are to persist something, they need to do the setup first and then test that it is still there.

- CI flow: a `preflight` job runs the script's syntax gate, clean workspace build, and AppSmokeTests before the matrix fan-out. Once that passes, each package runs `swift test` in its own job, the UI suite is split into focused groups (Navigation, Content Discovery, Playback, Batch Operations, Swipe Configuration), and `IntegrationTests` runs independently.
- UI/Integration jobs provision a dedicated simulator per suite (`zpod-<run_id>-<suite>`) with isolated DerivedData, then tear both down in `if: always()` cleanup steps.
- **Simulator Isolation Infrastructure** (supports 5+ parallel jobs):
  - **Staggered Provisioning**: Hash-based delays (0-8s) prevent simultaneous creation
  - **Capacity Monitoring**: Checks active simulator count, waits if ≥5 simulators exist
  - **Retry with Backoff**: Up to 3 attempts for creation with exponential delays (3s, 6s, 9s)
  - **Resource Detection**: Identifies resource exhaustion vs configuration errors  
  - **On-Demand Boot**: Simulators are created but NOT booted in CI; xcodebuild boots them on-demand to avoid concurrent boot contention (5 simulators booting simultaneously causes Data Migration hangs)
  - **Graceful Degradation**: Falls back to automatic destination if all retries fail
  - Matrix parallelism configurable via `max-parallel` (currently 5, can scale higher)
- The provisioning logic retries several device types (iPhone 16 → 13) so hosts missing the newest runtimes still get a compatible simulator; when none succeed the job falls back to the script's automatic destination selection.
- Preflight provisions its own simulator + DerivedData bundle (same candidate loop) and reuses those env vars for AppSmoke so early gating steps behave like the UI matrix.
- UI suites auto-build `zpod.app` inside the suite's DerivedData sandbox when `ZPOD_DERIVED_DATA_PATH` is set; this prevents linker failures when the test bundle expects a host app that hasn't been produced yet.

## 7.1. MCP Servers

Use these MCP servers for automation and diagnostics. Each server lists its commands and purpose.

### github

Repository, issue, and PR automation.

- `add_issue_comment`: Add a comment to an existing issue.
- `create_branch`: Create a new branch from a source branch (default: repo default).
- `create_issue`: Create a new issue.
- `create_or_update_file`: Create or update a single file (requires SHA for updates).
- `create_pull_request`: Open a new pull request.
- `create_pull_request_review`: Submit a review on a pull request.
- `create_repository`: Create a new repository (optionally with README).
- `fork_repository`: Fork a repository to a user or org.
- `get_file_contents`: Read a file or directory contents from a repo.
- `get_issue`: Fetch a specific issue.
- `get_pull_request`: Fetch a specific pull request.
- `get_pull_request_comments`: Fetch PR review comments.
- `get_pull_request_files`: List files changed in a PR.
- `get_pull_request_reviews`: List PR reviews.
- `get_pull_request_status`: Get combined status checks for a PR.
- `list_commits`: List commits for a branch or ref.
- `list_issues`: List issues with filters.
- `list_pull_requests`: List PRs with filters.
- `merge_pull_request`: Merge a PR (choose merge method).
- `push_files`: Push multiple files in a single commit.
- `search_code`: Search code across GitHub.
- `search_issues`: Search issues and PRs across GitHub.
- `search_repositories`: Search repositories.
- `search_users`: Search users.
- `update_issue`: Update an existing issue.
- `update_pull_request_branch`: Update PR branch from base.

### github_actions

Run and inspect GitHub Actions workflows.

- `run_logs`: Fetch logs for a workflow run.
- `run_status`: View status/details for a workflow run.
- `trigger_workflow`: Dispatch a workflow with inputs and ref.

### signing_manager

Code signing inventory.

- `list_identities`: List available signing identities.
- `list_profiles`: List provisioning profiles (filter by team or bundle prefix).

### sim_vision

Simulator visual inspection helpers.

- `sim_screenshot`: Capture a screenshot from the booted simulator (or named device).
- `sim_ui_tree`: Dump the accessibility/UI tree from the booted simulator.

### symbolication

Crash and symbol analysis.

- `atos_symbolicate`: Symbolicate an address using a binary or dSYM.
- `dwarfdump_uuid`: Show UUIDs for a dSYM.
- `list_dsyms`: Recursively find .dSYM bundles under a root.
- `symbolicate_crash`: Symbolicate a .crash file (optionally with dSYM).

### xcode_runner

Xcode build/test automation via `scripts/run-xcode-tests.sh`.

- `zpod_cleanup_logs`: Delete old logs by age.
- `zpod_full_pipeline`: Run the full default pipeline.
- `zpod_lint`: Run Swift lint gate.
- `zpod_run_builds`: Build targets via the helper script.
- `zpod_run_tests`: Run tests via the helper script.
- `zpod_self_check`: Run script self-check.
- `zpod_start_full_pipeline`: Start full pipeline asynchronously.
- `zpod_syntax`: Run Swift syntax checks.
- `zpod_task_status`: Check status/tail of an async task.
- `zpod_verify_testplan`: Verify test plan coverage.

### xcresult_explorer

Inspect `.xcresult` bundles.

- `xcresult_raw_get`: Fetch raw xcresult data (json/xml/human).
- `xcresult_summary`: Summarize build/test issues and failures.

## 7.2 SwiftLens (SwiftUI testing)

- The `zpod` app target depends on `SwiftLens`.
- The `AppSmokeTests`, `IntegrationTests`, and `zpodUITests` targets depend on `SwiftLensTestSupport`.
- Use SwiftLens for reliable SwiftUI UI testing and interaction; see <https://github.com/gahntpo/SwiftLens> for correct usage and APIs.

## 8. Issue & Documentation Management

- Create issues in `Issues/` when work falls outside an existing scope; name files `xx.y-description.md` to preserve ordering. Use sub-issue numbering (e.g. `17.1`) when inserting between existing IDs.
- Issue files must include description, acceptance criteria, spec references, dependencies, and testing strategy.
- Add TODO comments as `// TODO: [Issue #xx.y] Description`; remove them once the issue is resolved and update the issue accordingly.

### Dev Logs & Artifacts

- Maintain individual `dev-log/*.md` entries per issue; update with intent, progress, and timestamps (ET) as work evolves.
- **Update dev-logs incrementally**: Document intent before starting work, add findings during investigation, record solutions after each fix. Include dev-log updates in commits with related code changes when appropriate.
- **Implementation summaries**: Comprehensive post-completion documentation lives in `dev-log/implementation-summaries/` - see [README](dev-log/implementation-summaries/README.md) for details
- Store raw build/test outputs in `TestResults/TestResults_<timestamp>_<context>.log` (keep only the three most recent per test set).  This is done automatically by the ./scripts/run-xcode-tests.sh so you don't need to add to do anything extra when running the script
- Use `OSLog` for runtime logging inside the app.

## 9. CarPlay Development

For CarPlay-specific development, consult these specialized guides:

- **[CarPlay Setup Guide](docs/carplay/SETUP.md)** - Environment configuration, entitlements, simulator setup
- **[CarPlay HIG Compliance](docs/carplay/HIG_COMPLIANCE.md)** - Human Interface Guidelines validation, compliance checklist
- **[CarPlay Manual Testing Checklist](docs/carplay/MANUAL_TESTING_CHECKLIST.md)** - 44-scenario manual validation procedures

### Key CarPlay Requirements

- Use standard CarPlay templates (CPListTemplate, CPAlertTemplate, CPTabBarTemplate)
- Maintain 44pt minimum touch targets
- Keep list depths under 100 items
- Provide accessibility labels and hints for VoiceOver
- Avoid text entry and multi-step flows while driving
- Always include cancel actions in alerts

### Pull Requests

- Make sure you are doing updates regularly to the pull request, following the same strategy used for the dev-logs

---
When in doubt, consult the relevant spec or open a follow-up issue for clarification.

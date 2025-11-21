# UI Test Summary

This document outlines the UI testing approach for the main zpod application.

## Test Categories

### Core UI Navigation Tests (`CoreUINavigationTests.swift`)

**Purpose**: Verify main navigation flows and accessibility compliance

**Specifications Covered**:

- `spec/ui.md` - Navigating with CarPlay Layout
- `spec/ui.md` - Leveraging Accessibility Options  
- `spec/ui.md` - Optimizing for iPad UI
- `spec/ui.md` - Using App Shortcuts (iOS Quick Actions)

**Test Areas**:

- Main tab bar navigation
- Navigation stack management
- Accessibility labels and behaviors
- VoiceOver navigation flow
- iPad-specific layout adaptations
- Quick action handling
- Settings tab visibility and registry-backed feature navigation

### Playback UI Tests (`PlaybackUITests.swift`)

**Purpose**: Verify playback interface controls and platform integrations

**Specifications Covered**:

- `spec/ui.md` - Using Lock Screen and Control Center Players
- `spec/ui.md` - Controlling Playback via Headphones/Bluetooth
- `spec/ui.md` - Navigating with CarPlay Layout
- `spec/ui.md` - Apple Watch Support
- `spec/playback.md` - Player interface scenarios
- `Issues/03.1.1.1-mini-player-foundation.md` - Mini-player visibility and expansion

**Test Areas**:

- Now playing screen controls
- Lock screen media controls
- Control center integration
- CarPlay player interface
- Apple Watch playback controls
- Bluetooth control handling
- Mini-player visibility, transport controls, and expansion flow

### Content Discovery UI Tests (`ContentDiscoveryUITests.swift`)

**Purpose**: Verify search, browse, and discovery interface functionality

**Specifications Covered**:

- `spec/ui.md` - Voice Control for Search (Siri Integration)
- `spec/discovery.md` - Search and browse scenarios
- `spec/content.md` - Content browsing interfaces

**Test Areas**:

- Search interface and results display
- Browse and category navigation
- Subscription management UI
- Filter and sort controls
- Content recommendation displays

### Swipe Configuration UI Tests

**Purpose**: Validate the configurable swipe gesture workflow, ensure presets/haptics remain correct, and verify seeded swipe execution in the episode list.

**Specifications Covered**:

- `Issues/02.1-episode-list-management-ui.md` — Scenario 6: Swipe Gestures & Quick Actions
- `spec/ui.md` — Customizing Swipe Gestures section

**Suite Layout (12 tests across 6 files)**:

| File | Tests | Focus |
| --- | --- | --- |
| `SwipeConfigurationUIDisplayTests.swift` | 3 | Opens sheet from the gear button, verifies all sections render, validates default leading/trailing actions + haptic controls. |
| `SwipePresetSelectionTests.swift` | 3 | Applies Playback/Organization/Download presets, confirms save button enables, asserts rendered rows match preset expectations. |
| `SwipeToggleInteractionTests.swift` | 3 | Exercises haptic toggle, style picker, and full-swipe toggles (leading + trailing) using cached sheet containers. |
| `SwipeActionManagementTests.swift` | 1 | End-to-end workflow: add/remove/limit enforcement for leading/trailing actions without relaunching. |
| `SwipePersistenceTests.swift` | 1 | Seeds configuration via encoded payload, reopens sheet after relaunch, and verifies persisted actions + haptic state. |
| `SwipeExecutionTests.swift` | 1 | Seeds swipe actions, dismisses the sheet, and verifies leading/trailing swipe execution with instrumentation probes in the episode list. |

**Latest targeted runtimes (2025‑11‑19 runs via `./scripts/run-xcode-tests.sh -t …`)**:

| Suite | Tests | Phase Runtime | Result Log |
| --- | --- | --- | --- |
| SwipeConfigurationUIDisplayTests | 3 | ~7s test phase (`00:00:07` inside `TestResults/TestResults_20251119_080416_test_zpodUITests-SwipeConfigurationUIDisplayTests.log`) | `TestResults/TestResults_20251119_080416_test_zpodUITests-SwipeConfigurationUIDisplayTests.log` |
| SwipePresetSelectionTests | 3 | ~6s test phase | `TestResults/TestResults_20251119_080603_test_zpodUITests-SwipePresetSelectionTests.log` |
| SwipeToggleInteractionTests | 3 | ~7s test phase | `TestResults/TestResults_20251119_080727_test_zpodUITests-SwipeToggleInteractionTests.log` |
| SwipeActionManagementTests | 1 | ~4s test phase | `TestResults/TestResults_20251119_080850_test_zpodUITests-SwipeActionManagementTests.log` |
| SwipePersistenceTests | 1 | ~69s test phase (includes seeded relaunch) | `TestResults/TestResults_20251119_083334_test_zpodUITests-SwipePersistenceTests.log` |
| SwipeExecutionTests | 1 | ~63s test phase (includes seeded relaunch + swipe probes) | `TestResults/TestResults_20251119_084032_test_zpodUITests-SwipeExecutionTests.log` |

Each test phase time excludes the initial build (handled once by preflight). The persistence/execution suites are intentionally longer because they seed defaults, relaunch once, and wait for debug-state streams before verifying the episode list instrumentation.

**Shared Support**: `SwipeConfigurationTestSupport.swift` provides the base class plus modular extensions (Navigation, ActionManagement, Toggle, Debug, etc.). `reuseOrOpenConfigurationSheet(resetDefaults:)` caches the SwiftUI sheet container after a single readiness gate so later assertions run without redundant navigation. `launchSeededApp(resetDefaults:)` enforces a single launch per seed payload.

**Test Areas**:

- Configuring leading/trailing swipe actions via presets and custom toggles
- Persisting haptic feedback settings and verifying style selection across launches
- Verifying full-swipe execution toggles persist after saving and relaunching, using debug summary state checks
- Ensuring haptic feedback can be disabled and re-enabled with style selection preserved across consecutive launches
- Exercising configured swipe buttons within `EpisodeListView`, including playlist selection flows
- Accessibility identifier coverage for configuration controls and rendered swipe buttons
- Validates that preset buttons respond directly under automation (no manual fallback) and enforces the three-action cap via the add-action picker sheet

**CI Strategy (Hybrid Tier Architecture per Issue #02.6.3)**:

- The preflight job builds zpod.app + test bundles once and uploads the derived data artifact.
- Six swipe jobs (`UITests-SwipeUIDisplay`, `…-SwipePresetSelection`, `…-SwipeToggleInteraction`, `…-SwipeActionManagement`, `…-SwipePersistence`, `…-SwipeExecution`) download the preflight artifact, reuse the host app, and run in parallel.
- Each job provisions its own simulator/derived data sandbox, so no derived data sharing or “test-without-building” hazards.
- Target total swipe time: ≤6 minutes in parallel (vs ≥20 minutes before the decomposition). Latest Actions runs 
  (recorded 2025‑11‑19) keep individual swipe jobs under 70s after the preflight artifact is restored.

### Widget and Extension Tests (`WidgetExtensionTests.swift`)

**Purpose**: Verify home screen widgets and app extensions

**Specifications Covered**:

- `spec/ui.md` - Using Home Screen Widgets (iOS Widgets)
- `spec/ui.md` - Notification Actions
- `spec/ui.md` - Siri and Shortcuts Integration

**Test Areas**:

- Widget display and updates
- Widget interaction handling
- Notification action responses
- Siri shortcuts execution
- Extension activation

## UI Testing Framework

### Test Structure

- All UI tests use XCUIApplication for app launch and interaction
- Tests follow Given/When/Then structure with clear comments
- Each test is isolated and can run independently

### Event-Driven Waiting Pattern

- Uses XCUITest's native `waitForExistence()` and XCTestExpectation patterns
- No artificial `Thread.sleep()` or polling - responds to actual UI events
- Timeout = Failure: tests fail immediately when elements don't appear within timeout
- Helper functions: `waitForElement()`, `waitForAnyElement()`, `waitForLoadingToComplete()`

### Adaptive Timeout Scaling (Issue 12.7)

- **Timeout Scale Factor**: Controlled via `UITEST_TIMEOUT_SCALE` environment variable
  - Local default: 1.0 (no scaling)
  - CI default: 1.5 (50% longer timeouts for hosted runners)
  - Custom: Set `UITEST_TIMEOUT_SCALE=2.0` for slower environments
- **Base Timeouts**:
  - `adaptiveTimeout`: 10s local → 30s CI (20s base × 1.5 scale)
  - `adaptiveShortTimeout`: 5s local → 15s CI (10s base × 1.5 scale)
- **CI Diagnostics**: On timeout, helpers emit `app.debugDescription` to show accessibility tree
  - Helps debug failures without manual reproduction
  - Only active in CI to avoid local log noise

### Accessibility Testing

- All UI tests include accessibility verification
- VoiceOver labels and hints are validated
- Keyboard navigation is tested where applicable
- Color contrast and sizing compliance is verified

### Platform-Specific Testing

- iPhone-specific behaviors are tested on iPhone simulators
- iPad adaptations are tested on iPad simulators
- CarPlay integration is tested using CarPlay simulator
- Apple Watch behaviors are tested using paired watch simulator

### Test Data and State Management

- UI tests use consistent test data and app state
- Tests reset app state before execution
- Mock services are configured for reliable testing
- External dependencies are isolated

### Performance and Reliability

- Launch performance is measured and validated
- UI responsiveness is tested under load
- Memory usage during UI operations is monitored
- Battery impact of UI operations is considered

## Test Execution

### Automation

- All UI tests run in CI/CD pipeline
- Tests execute on multiple device configurations
- Screenshot capture on test failures
- Video recording for complex interaction flows

### Manual Testing Guidelines

- Manual testing supplements automated UI tests
- Focus on subjective user experience aspects
- Validation of animations and transitions
- Real device testing for platform-specific features

## Coverage Metrics

### User Journey Coverage

- Complete user workflows are tested end-to-end
- Critical paths receive priority testing attention
- Edge cases and error scenarios are included

### Interface Element Coverage

- All interactive elements are tested
- Navigation patterns are validated
- Form inputs and validation are verified
- Media controls and feedback are tested

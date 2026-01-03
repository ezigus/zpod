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

### Mini-Player Persistence Tests (`MiniPlayerPersistenceTests.swift`)

**Purpose**: Validate mini-player persistence, quick play entry, and VoiceOver labels.

**Specifications Covered**:

- `Issues/03.1.1.1-mini-player-foundation.md` - persistence across navigation and accessibility labels
- `Issues/03.2-mini-player-bottom-overflow.md` - tab bar remains tappable with mini-player active

**Test Areas**:

- Mini-player persistence across tab switches and navigation back/forward
- Quick play from Library triggers mini-player without leaving the list
- VoiceOver labels for mini-player transport controls and metadata
- Tab bar buttons remain tappable while the mini-player is visible

### Playback Position UI Tests (`PlaybackPositionUITests.swift`)

**Purpose**: Validate position ticking engine integration with UI layer

**Specifications Covered**:

- `spec/playback.md` - Timeline Advancement During Playback
- `spec/playback.md` - Pausing Playback
- `spec/playback.md` - Resuming Playback
- `spec/playback.md` - Seeking to Position
- `Issues/03.3.1-position-ticking-engine.md` - Position ticker acceptance criteria

**Test Areas**:

- Position advancement during playback (ticker integration)
- Pause/resume position persistence
- Seeking updates position immediately
- Playback speed affects position advancement
- Episode finish detection at duration

**Test Coverage** (5 tests):

1. `testExpandedPlayerProgressAdvancesDuringPlayback` - Verifies ticker advances position over time
2. `testPausingStopsProgressAdvancement` - Confirms position freezes when paused
3. `testResumingContinuesProgressAdvancement` - Validates position resumes from saved
4. `testSeekingUpdatesPositionImmediately` - Ensures seek doesn't wait for next tick
5. `testPlaybackSpeedAffectsProgressRate` - Confirms speed scaling works (0.8x-5.0x)

**Note**: These tests validate the UI-layer integration of Issue 03.3.1 (Position Ticking Engine). The engine-layer unit tests (19 tests) are in `Packages/PlaybackEngine/Tests/EnhancedEpisodePlayerTickerTests.swift`.

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

### Test Coverage Matrix (12 tests → Spec Traceability)

| # | Test File | Test Method | Spec Ref | Validates |
| --- | --- | --- | --- | --- |
| 1 | `SwipeConfigurationUIDisplayTests` | `testConfigurationSheetOpensFromEpisodeList()` | Issue #02.6.3 - UI Display Test 1 | Sheet opens from episode list, all UI elements materialize and are accessible |
| 2 | `SwipeConfigurationUIDisplayTests` | `testAllSectionsAppearInSheet()` | Issue #02.6.3 - UI Display Test 2 | All configuration sections (haptics, full-swipe, add actions, presets) materialize correctly via scrolling |
| 3 | `SwipeConfigurationUIDisplayTests` | `testDefaultActionsDisplayCorrectly()` | Issue #02.6.3 - UI Display Test 3 | Default actions match factory settings (Leading: "Mark Played", Trailing: "Delete", "Archive") |
| 4 | `SwipePresetSelectionTests` | `testPlaybackPresetAppliesCorrectly()` | Issue #02.6.3 - Preset Selection Test 1 | Playback preset applies correct configuration (Leading: Play, Add to Playlist; Trailing: Download, Favorite) |
| 5 | `SwipePresetSelectionTests` | `testOrganizationPresetAppliesCorrectly()` | Issue #02.6.3 - Preset Selection Test 2 | Organization preset applies correct configuration (Leading: Mark Played, Favorite; Trailing: Archive, Delete) |
| 6 | `SwipePresetSelectionTests` | `testDownloadPresetAppliesCorrectly()` | Issue #02.6.3 - Preset Selection Test 3 | Download preset applies correct configuration (Leading: Download, Mark Played; Trailing: Archive, Delete) |
| 7 | `SwipeToggleInteractionTests` | `testHapticToggleEnablesDisables()` | Issue #02.6.3 - Toggle Interaction Test 1 | Haptic feedback toggle updates draft state correctly and persists across multiple toggle operations |
| 8 | `SwipeToggleInteractionTests` | `testHapticStylePickerChangesValue()` | Issue #02.6.3 - Toggle Interaction Test 2 | Haptic style picker (Soft/Medium/Rigid) responds to taps and is visible only when haptics enabled |
| 9 | `SwipeToggleInteractionTests` | `testFullSwipeToggleLeadingTrailing()` | Issue #02.6.3 - Toggle Interaction Test 3 | Full-swipe toggles operate independently for leading/trailing edges and update draft state correctly |
| 10 | `SwipeActionManagementTests` | `testManagingActionsEndToEnd()` | Issue #02.6.3 - Action Management Test (Consolidated) | Complete workflow: add actions to cap (3 max), verify limit enforcement, remove actions, add trailing actions |
| 11 | `SwipePersistenceTests` | `testSeededConfigurationPersistsAcrossControls()` | Issue #02.6.3 - Persistence Test (Consolidated) | Seeded configurations via UserDefaults persist correctly: actions, full-swipe toggles, haptic settings all survive relaunch |
| 12 | `SwipeExecutionTests` | `testLeadingAndTrailingSwipesExecute()` | Issue #02.6.3 - Execution Test (Consolidated) | Seeded swipe actions execute correctly from episode list with proper action button display and execution recording |

### Scenario Coverage Summary

| Scenario Category | Tests | Coverage Status |
| --- | --- | --- |
| **UI Display & Materialization** | Tests 1-3 | ✅ Complete: Sheet opening, section visibility, default configuration rendering |
| **Preset Application** | Tests 4-6 | ✅ Complete: All 3 presets (Playback, Organization, Download) apply correct configurations |
| **Toggle Interactions** | Tests 7-9 | ✅ Complete: Haptic toggle, style picker, full-swipe toggles (both edges) |
| **Action Management** | Test 10 | ✅ Complete: Add/remove actions, limit enforcement (3-action cap) |
| **Persistence** | Test 11 | ✅ Complete: UserDefaults seeding persists across all configuration controls |
| **Execution** | Test 12 | ✅ Complete: Swipe gestures execute configured actions on both edges |

### Spec → Test Mapping

- `Issues/02.1-episode-list-management-ui.md` Scenario 6 (Swipe Gestures): Tests 1-12
- `spec/ui.md` Customizing Swipe Gestures: Tests 4-6 (presets), Tests 7-9 (toggles)
- Issue #02.6.3 Acceptance Criteria: All 12 tests provide complete coverage of decomposed scenarios

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

### Index-Based Collection Enumeration

The SwipeConfiguration test infrastructure uses explicit index-based enumeration (`element(boundBy: i)`) instead of relying solely on `.firstMatch` when searching for UI elements. This pattern is necessary due to XCUITest's limitations with SwiftUI's dynamic view hierarchy.

**Why Index-Based Enumeration Is Required**:

1. **SwiftUI Sheet Window Ambiguity**: SwiftUI sheets can appear in multiple windows depending on:
   - iPad split-view configurations
   - Multi-scene setups
   - Runtime presentation context (sheet vs fullScreenCover vs popover)

2. **Container Type Variability**: The SwiftUI List in `SwipeActionConfigurationView` may be backed by:
   - `UITableView` (appears as `.table` in XCUITest)
   - `UICollectionView` (appears as `.collectionView`)
   - `UIScrollView` (appears as `.scrollView`)
   - The backing type can change between iOS versions or SwiftUI updates

3. **FirstMatch Unreliability**: Using `.firstMatch` alone fails when:
   - Multiple containers exist with similar content
   - The first match in hierarchy order isn't the visible/active sheet
   - SwiftUI renders placeholder/offscreen containers that match the predicate

### Implementation Pattern

(SwipeConfigurationTestSupport+SheetUtilities.swift:40-84):

```swift
// Enumerate ALL windows to find candidates
let windows = app.windows.matching(NSPredicate(value: true))
for i in 0..<windows.count {
  let win = windows.element(boundBy: i)
  // Check if window contains swipe-related elements
  if win.descendants(matching: .any)["Swipe Actions"].exists {
    candidateWindows.append(win)
  }
}

// For each candidate window, enumerate ALL potential container types
func searchContainer(in root: XCUIElement) -> XCUIElement? {
  // Try tables
  let tables = root.tables.matching(NSPredicate(value: true))
  for i in 0..<tables.count {
    let table = tables.element(boundBy: i)
    if table.exists && containsSwipeElements(table) {
      return table
    }
  }

  // Try collections
  let collections = root.collectionViews.matching(NSPredicate(value: true))
  for i in 0..<collections.count {
    let candidate = collections.element(boundBy: i)
    if candidate.exists && containsSwipeElements(candidate) {
      return candidate
    }
  }

  // Try scroll views as fallback
  // ... similar pattern
}
```

**Optimization Strategy**: The current implementation combines defensive enumeration with fast-path optimization:
- **Fast path** (lines 34-38): Try explicit identifier lookup first (`SwipeActions.List`)
- **Defensive fallback** (lines 40-86): If fast path fails, enumerate all possibilities
- **Result**: Typical case resolves in <100ms; worst case still succeeds within 500ms

### When To Use This Pattern
- ✅ **Use** for discovering SwiftUI sheets/modals where container type is unknown
- ✅ **Use** when multiple windows might contain matching elements
- ✅ **Use** when SwiftUI backing view type varies across iOS versions
- ❌ **Avoid** for simple element lookups within a known container (use `.firstMatch`)
- ❌ **Avoid** when accessibility identifier uniquely identifies the element

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

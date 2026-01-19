---
title: Isolated UI Test Infrastructure
---

# Isolated UI Test Infrastructure

## Purpose

The new `IsolatedUITestCase` + page-object stack replaces the fragmented setup/cleanup logic previously spread across every UI test. This document summarizes how to use the shared infrastructure and where to find the migration reference material.

## Key pieces

1. **`IsolatedUITestCase`** (`zpodUITests/IsolatedUITestCase.swift`)
   - Clears UserDefaults and Keychain before/after each test.
   - Handles CI-specific app termination (via `performPreTestCleanup()`/`performPostTestCleanup()`).
   - Conforms `sync` tests to `SmartUITesting` so they get `waitForElement`, `launchConfiguredApp()`, etc.
   - Override `userDefaultsSuite` in subclasses (example: swipe suite overrides `swipeDefaultsSuite`).

2. **Unified wait helpers**
   - `UITestWait.swift` exposes `WaitCondition` and `tapWhenReady()` so tests can express waits once instead of 14+ ad-hoc helpers.
   - Page objects call `BaseScreen.waitForAny()` and the new page objects (`TabBarNavigation`, `SettingsScreen`, etc.) to share fallback logic.

3. **Page objects**
   - `TabBarNavigation`, `SettingsScreen`, and future objects (Discover, Library, Player) encapsulate navigation/verification and reduce duplicate wait/scroll code.
   - Swipe-specific helpers still live under `SwipeConfigurationTestSupport+*.swift` but call into `IsolatedUITestCase` when they launch/relaunch.

## How to run the migrated suites

Phase 2 (swipe suite) uses the following commands:

```
./scripts/run-xcode-tests.sh -t SwipeActionManagementTests,SwipeConfigurationUIDisplayTests
./scripts/run-xcode-tests.sh -t SwipePersistenceTests
./scripts/run-xcode-tests.sh -t SwipeExecutionTests
./scripts/run-xcode-tests.sh -t SwipeToggleInteractionTests
./scripts/run-xcode-tests.sh -t SwipePresetSelectionTests
```

Once the swipe helper migration is complete, refer to `dev-log/12.3-phase-2-swipeconfiguration-design.md` for progress notes, risks, and the Mermaid diagram linking `IsolatedUITestCase`, the page objects, and the swipe helpers.

## Next phases

- Phase 3: migrate `ContentDiscoveryUITests`, `PlayerNavigationTests`, `PlaybackUITests` and related page objects.
- Phase 4: bring the playback position suite into the same base.
- Phase 5: finish the remaining player/batch/episode tests and ensure every suite inherits `IsolatedUITestCase`.

Each phase should update the dev-log entry (`dev-log/12.3-ui-test-migration-plan.md`) and keep the doc above in sync when the new pages or page objects are introduced.

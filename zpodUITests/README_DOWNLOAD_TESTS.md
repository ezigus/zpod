# Download Flow UI Tests

## Overview

The `DownloadFlowUITests.swift` test suite validates the episode download functionality end-to-end through the user interface.

**Created for:** Issue 28.1 - Phase 4: Test Infrastructure
**Spec Coverage:** `spec/offline-playback.md`
**CI Matrix:** `UITests-DownloadFlow`

## Test Coverage

### ✅ Implemented Tests

1. **testSwipeToDownloadEpisode**
   - Verifies user can swipe on episode and tap "Download"
   - Confirms download action button appears and is tappable
   - Spec: offline-playback.md - "User swipes to download episode"

2. **testDownloadProgressIndicatorDisplays**
   - Verifies progress indicator shows during download
   - Looks for download icon, progress bar, or "Downloading" text
   - Spec: offline-playback.md - "Download shows progress"

3. **testDownloadedEpisodeShowsBadge**
   - Verifies completed download shows badge (filled checkmark)
   - Tests pre-downloaded episode scenario
   - Spec: offline-playback.md - "Downloaded episode shows badge"

4. **testBatchDownloadMultipleEpisodes**
   - Verifies multi-select mode batch download
   - Tests selecting multiple episodes and downloading all
   - Spec: offline-playback.md - "User selects multiple episodes"

5. **testPauseAndResumeDownload**
   - Verifies download can be paused and resumed
   - Tests pause/resume button toggling
   - Spec: offline-playback.md - "User cancels download"

6. **testFailedDownloadShowsRetryButton**
   - Verifies failed download shows error indicator
   - Tests retry button availability
   - Spec: offline-playback.md - "Download fails, user can retry"

### ⏳ Future Test Opportunities

The following scenarios from `spec/offline-playback.md` could be added as test coverage expands:

1. **Network simulation tests**
   - Test downloads with slow network conditions
   - Test downloads with network interruptions
   - Requires: Network Link Conditioner integration

2. **Storage management tests**
   - Test download when storage is full
   - Test automatic cleanup of old downloads
   - Requires: Phase 2 (Storage Management UI) completion

3. **Offline playback tests**
   - Test playing downloaded episode in airplane mode
   - Test local file preference over streaming
   - Requires: Actual download infrastructure working

## Test Environment Flags

The tests use environment variables to control behavior for testing:

- `UITEST_DOWNLOAD_SIMULATION_MODE=1` - Enable download simulation
- `UITEST_PREDOWNLOAD_FIRST_EPISODE=1` - Pre-download first episode for testing
- `UITEST_SIMULATE_DOWNLOAD_FAILURE=1` - Simulate download failure

**Note:** These flags are **not yet implemented** in the app. They are placeholders for future test infrastructure enhancements.

## CI Integration

The download tests run as a separate matrix entry in `.github/workflows/ci.yml`:

```yaml
- name: UITests-DownloadFlow
  tests: zpodUITests/DownloadFlowUITests
```

### Benefits of Separate Matrix Entry:

1. **Isolation** - Download tests run in their own simulator with dedicated DerivedData
2. **Parallelism** - Can run concurrently with other UI test suites (max-parallel: 5)
3. **Clarity** - Clear CI job name makes it easy to identify download test failures
4. **Performance** - Download-specific failures don't block other UI tests

## Running the Tests

### Locally

```bash
# Run just the download tests
./scripts/run-xcode-tests.sh -t zpodUITests/DownloadFlowUITests

# Run all UI tests
./scripts/run-xcode-tests.sh -t zpodUITests
```

### In CI

The tests run automatically on:
- Push to `main` branch
- Pull requests to `main` branch
- Manual workflow dispatch (select "all" or "ui" matrix)

## Test Architecture

### Base Class: `IsolatedUITestCase`

All download tests inherit from `IsolatedUITestCase`, which provides:

- Automatic UserDefaults cleanup (prevents state pollution)
- Automatic Keychain cleanup (prevents credential leaks)
- `SmartUITesting` protocol (wait helpers, navigation, launch)
- CI-aware app termination (prevents resource exhaustion)
- `continueAfterFailure = false` (fast failure detection)

### Helper Methods

- `navigateToEpisodeList()` - Navigate from app launch to episode list view
- `episodeListLandingElements()` - Define expected elements in episode list
- Uses `waitForLoadingToComplete()` from `SmartUITesting`
- Uses `navigateAndWaitForResult()` from `SmartUITesting`
- Uses `waitForAnyElement()` from `SmartUITesting`

### Test Pattern

All tests follow Given-When-Then structure:

```swift
@MainActor
func testFeature() throws {
    // Given: Initial state setup
    app = launchConfiguredApp()
    navigateToEpisodeList()

    // When: User action
    let element = app.buttons["Action"]
    element.tap()

    // Then: Verify outcome
    XCTAssertTrue(expectedResult, "Expected behavior")
}
```

## Known Limitations

1. **Environment Flags Not Implemented**
   - Test environment flags (e.g., `UITEST_DOWNLOAD_SIMULATION_MODE`) are documented but not yet wired up in the app
   - Current tests verify UI structure but not actual download behavior
   - **Fix:** Implement test-only download simulation in Phase 4

2. **No Network Simulation**
   - Cannot test slow network, interrupted downloads, or network recovery
   - **Fix:** Integrate Network Link Conditioner or URLSession mocking in Phase 4

3. **No Actual Downloads**
   - Tests verify UI interactions but don't verify real file downloads
   - **Fix:** Add integration tests that actually download small test audio files

4. **Limited Error Scenarios**
   - Only tests failure indicator UI, not actual error conditions
   - **Fix:** Implement error injection via test environment flags

## Future Enhancements

### Phase 4 Improvements (Short-Term)

1. **Implement Test Environment Flags**
   - Add `DownloadSimulationManager` for test-only download control
   - Wire flags to simulate downloads, failures, pre-downloaded states
   - Enable actual download behavior verification

2. **Network Simulation Helpers**
   - Create `NetworkSimulationManager` for URLSession mocking
   - Add helpers for slow network, interrupted downloads
   - Test retry logic and error recovery

3. **Integration Tests**
   - Create small test audio files for actual downloads
   - Verify local file storage and playback
   - Test cleanup and deletion

### Long-Term Improvements

1. **Visual Regression Tests**
   - Snapshot testing for download status badges
   - Verify progress bar appearance
   - Compare error states visually

2. **Performance Tests**
   - Measure time to initiate download
   - Verify UI responsiveness during download
   - Test batch download performance with 10+ episodes

3. **Accessibility Tests**
   - VoiceOver announcements for download status
   - Keyboard navigation through download actions
   - Dynamic Type support verification

## Related Documentation

- **Implementation Plan:** `ISSUE_28.1_STATUS.md`
- **Dev Log:** `dev-log/28.1.1-download-manager.md`
- **Spec:** `spec/offline-playback.md`
- **Architecture:** `Packages/LibraryFeature/Sources/LibraryFeature/DownloadCoordinatorBridge.swift`

## Questions?

- For test failures, check `TestResults/` directory for `.xcresult` bundles
- For CI failures, check GitHub Actions logs for the `UITests-DownloadFlow` job
- For test infrastructure, see `zpodUITests/IsolatedUITestCase.swift`
- For test patterns, see `docs/testing/UI_TESTING_ADVANCED_PATTERNS.md`

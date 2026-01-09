# Playback Position Testing Guide

**Issue**: 03.3.2 - AVPlayer Playback Engine

**Last Updated**: 2026-01-04

## Overview

Playback position tests validate that the UI correctly reflects playback state (position, play/pause, seeking) from the underlying playback engine. These tests run in **two modes** to ensure both the UI logic and audio engine integration work correctly.

## Dual-Mode Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     UI Tests                                │
│  ┌─────────────────────┐    ┌─────────────────────────┐    │
│  │ Ticker Tests        │    │ AVPlayer Tests          │    │
│  │ (Deterministic)     │    │ (Integration)           │    │
│  └──────────┬──────────┘    └──────────┬──────────────┘    │
│             │                          │                    │
│             ▼                          ▼                    │
│  ┌─────────────────────┐    ┌─────────────────────────┐    │
│  │ UITEST_DISABLE_     │    │ (No flag = Production)  │    │
│  │ AUDIO_ENGINE=1      │    │                         │    │
│  └──────────┬──────────┘    └──────────┬──────────────┘    │
└─────────────┼─────────────────────────┼────────────────────┘
               │                          │
               ▼                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  EnhancedEpisodePlayer                      │
│  ┌─────────────────────┐    ┌─────────────────────────┐    │
│  │ TimerTicker         │    │ AVPlayerPlaybackEngine  │    │
│  │ (0.5s timer)        │    │ (0.5s time observer)    │    │
│  └─────────────────────┘    └─────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## When to Use Each Mode

| Use Case | Mode | Rationale |
|----------|------|-----------|
| CI regression | Both | Catches UI bugs (ticker) and integration bugs (AVPlayer) |
| Local development | Ticker | Fast feedback, no audio needed |
| Debugging audio issues | AVPlayer | Validates real audio path |
| New feature development | Ticker first | Faster iteration, then AVPlayer for validation |
| Performance testing | AVPlayer | Measures real-world audio overhead |
| UI-only changes | Ticker | AVPlayer tests would be redundant |

## Test Structure

### Test Files

| File | Purpose | Lines | Mode |
|------|---------|-------|------|
| `PlaybackPositionTestSupport.swift` | Shared protocol with navigation/assertion helpers | ~200 | N/A |
| `PlaybackPositionTickerTests.swift` | Ticker mode tests (5 core tests) | ~180 | Ticker |
| `PlaybackPositionAVPlayerTests.swift` | AVPlayer mode tests (5 core + 4 edge-case tests) | ~560 | AVPlayer |
| `PlaybackPositionUITests.swift` | **DEPRECATED** - Original tests | ~300 | Ticker (implicit) |

### Test Scenarios (Both Suites)

All scenarios map to `zpod/spec/playback.md` - Core Playback Behavior:

#### Core Position Tests

| Test Method | Spec Reference | Validates |
|-------------|----------------|-----------|
| `testExpandedPlayerProgressAdvancesDuringPlayback` | Timeline Advancement During Playback | Position increases while playing |
| `testPositionStopsAdvancingWhenPaused` | Pausing Playback | Position freezes when paused |
| `testPositionResumesAdvancingAfterPause` | Resuming Playback | Position continues after resume |
| `testSeekingUpdatesPositionImmediately` | Seeking to Position | Seek updates position, playback continues |
| `testMiniPlayerReflectsPlaybackState` | Timeline Advancement (Mini-Player) | Mini-player shows correct state |

#### Edge-Case Tests (AVPlayer Only - Issue 03.3.2.7)

| Test Method | Spec Reference | Status | Validates |
|-------------|----------------|--------|-----------|
| `testPlaybackSpeedChangesPositionRate` | Playing Episode with Custom Speed | ✅ Passing | 2x speed advances position ~2x faster |
| `testInterruptionPausesAndResumesPlayback` | Audio Interruption Handling | ⏸️ Skipped | Debug UI visibility issue |
| `testMissingAudioURLShowsErrorNoRetry` | Episode Missing Audio URL | ✅ Passing | Missing-audio error UI now surfaces message and no retry button (03.3.4) |
| `testNetworkErrorShowsRetryAndRecovers` | Network Error + Retry | ✅ Passing | Network error UI exposes retry button (03.3.4) |

**Note**: Edge-case tests validate scenarios beyond basic position/seek behavior. Missing-audio and network-error paths now pass, bringing Issue 03.3.2.7 to 90% completion (9/10 tests); only the interruption test remains skipped due to the debug control visibility issue described above.

**Total Coverage**: 14 tests (5 ticker + 9 AVPlayer) validating 9 scenarios

## Key Implementation Details

### Shared Support Protocol

Both test classes conform to `PlaybackPositionTestSupport`, which provides:

- **Navigation**: `startPlayback()`, `expandPlayer()`
- **Slider Queries**: `getSliderValue()`, `extractCurrentPosition(from:)`
- **Waiting**: `waitForPositionAdvancement(beyond:timeout:)`
- **Stabilization**: `waitForUIStabilization(afterSeekingFrom:...)`
- **Stability**: `verifyPositionStable(at:forDuration:tolerance:)`
- **Logging**: `logSliderValue(_:value:)`, `logBreadcrumb(_:)`

**Benefits**:
- Zero code duplication between test classes
- Consistent navigation logic
- Easier maintenance (update once, both suites benefit)
- Clear separation of concerns (protocol = helpers, tests = scenarios)

### Mode Differences

| Aspect | Ticker Tests | AVPlayer Tests |
|--------|--------------|----------------|
| **Timeout** | 5s | 10s (buffering time) |
| **Position tolerance** | ±0.1s | ±0.5s (real-time jitter) |
| **Position source** | TimerTicker (deterministic) | AVPlayer time observer |
| **Audio output** | None | Real audio streams |
| **CI execution time** | ~15 seconds | ~30-45 seconds |
| **Flakiness risk** | Low | Medium (network/hardware) |
| **Environment** | `UITEST_DISABLE_AUDIO_ENGINE=1` | No flag (production path) |
| **What it validates** | UI state management, control logic | AVPlayer → UI integration pipeline |

### AVPlayer Tolerances

AVPlayer tests use relaxed tolerances to account for:
- Network buffering delays (1-3 seconds on first play)
- Real-time jitter in position callbacks (±0.1-0.5s typical)
- Asynchronous seek completion (0.5-2 seconds)

| Parameter | Ticker | AVPlayer | Reason for Difference |
|-----------|--------|----------|----------------------|
| Advancement timeout | 5s | 10s | AVPlayer needs time to buffer/connect |
| Position tolerance | ±0.1s | ±0.5s | AVPlayer may fire one callback after pause |
| Stability window | 0.3s | 0.5s | Longer for async seek completion |
| Seek timeout | 3s | 5s | Network latency for remote media |

## CI Integration

### Jobs

| Job Name | Tests | Timeout | Execution Time | Blocking |
|----------|-------|---------|----------------|----------|
| `UITests-PlaybackTicker` | PlaybackPositionTickerTests (5) | 10 min | ~3 min | ✅ Yes |
| `UITests-PlaybackAVPlayer` | PlaybackPositionAVPlayerTests (5) | 15 min | ~5 min | ✅ Yes |

**Total CI Impact**: +5 minutes (runs in Wave 2 after other UI tests)

### Failure Triage

| Failure Type | Likely Cause | Action |
|--------------|--------------|--------|
| **Ticker only fails** | UI logic bug | Debug immediately - ticker tests are deterministic |
| **AVPlayer only fails** | Audio engine issue | Check AVPlayerPlaybackEngine integration |
| **Both fail** | Common infrastructure | Check PlaybackPositionTestSupport helpers |
| **Flaky AVPlayer** | Network/timing | Increase tolerance, check CI logs for timeouts |
| **Both flaky** | UI timing issue | Check SmartUITesting adaptive timeouts |

## Running Tests Locally

### Run Both Suites

```bash
# Full playback test regression
./scripts/run-xcode-tests.sh -t zpodUITests/PlaybackPositionTickerTests,zpodUITests/PlaybackPositionAVPlayerTests

# Expected output:
# Test Suite 'PlaybackPositionTickerTests' passed (5 tests in ~15s)
# Test Suite 'PlaybackPositionAVPlayerTests' passed (5 tests in ~90s)
```

### Run Ticker Tests Only (Fast)

```bash
./scripts/run-xcode-tests.sh -t zpodUITests/PlaybackPositionTickerTests

# Expected output:
# Executed 5 tests, with 0 failures (0 unexpected) in 14.234 (14.567) seconds
```

### Run AVPlayer Tests Only (Real Audio)

```bash
./scripts/run-xcode-tests.sh -t zpodUITests/PlaybackPositionAVPlayerTests

# Expected output:
# Executed 5 tests, with 0 failures (0 unexpected) in 87.456 (88.123) seconds
```

### Enable Debug Logging

```bash
# Set environment variable for verbose position logging
export UITEST_POSITION_DEBUG=1
./scripts/run-xcode-tests.sh -t zpodUITests/PlaybackPositionTickerTests
```

## Adding New Tests

### When to Add a New Test

Add a new test when:
- New playback feature affects position display
- New spec scenario for playback behavior
- Bug found that existing tests don't catch
- New edge case discovered (e.g., very long episodes)

### Steps to Add a Test

1. **Update Both Test Classes**
   - Add test method to `PlaybackPositionTickerTests.swift`
   - Add identical test method to `PlaybackPositionAVPlayerTests.swift`
   - Use same Given/When/Then structure in both

2. **Use Appropriate Timeouts**
   - Ticker tests: Use 5s timeout
   - AVPlayer tests: Use `avplayerTimeout` constant (10s)

3. **Use Shared Helpers**
   - Always use helpers from `PlaybackPositionTestSupport`
   - Don't duplicate navigation logic
   - Reuse position assertion helpers

4. **Add Spec Reference**
   - Document which spec scenario the test validates
   - Use `/// **Spec**: <scenario name>` format
   - Include Given/When/Then in comments

5. **Run Locally First**
   ```bash
   # Test ticker mode
   ./scripts/run-xcode-tests.sh -t zpodUITests/PlaybackPositionTickerTests
   
   # Test AVPlayer mode
   ./scripts/run-xcode-tests.sh -t zpodUITests/PlaybackPositionAVPlayerTests
   ```

6. **Monitor CI for Flakiness**
   - Watch first 3 CI runs
   - If AVPlayer test flaky, increase timeout
   - If both flaky, issue is in shared infrastructure

### Example: Adding a Playback Speed Test

```swift
// In PlaybackPositionTickerTests.swift
/// **Spec**: Playback Speed Control
/// **Given**: An episode is playing at 1.0x speed
/// **When**: User changes speed to 2.0x
/// **Then**: Position advances at 2x rate
@MainActor
func testPlaybackSpeedAffectsPositionAdvancement() throws {
    launchApp()
    guard startPlayback(), expandPlayer() else {
        XCTFail("Failed to start playback")
        return
    }
    
    // Change speed to 2.0x (implementation details...)
    // Measure advancement rate
    // Assert position advanced at 2x rate
}

// In PlaybackPositionAVPlayerTests.swift
/// **Spec**: Playback Speed Control
/// **Critical**: Validates AVPlayer.rate property integration
@MainActor
func testPlaybackSpeedAffectsPositionAdvancement() throws {
    launchApp()
    guard startPlayback(), expandPlayer() else {
        XCTFail("Failed to start playback")
        return
    }
    
    // Same test logic, but validates real AVPlayer.rate changes
    // Use avplayerTimeout for longer buffering
}
```

## Troubleshooting

### "Progress slider should have advanced" failure

**Ticker Test Failure**:
- Check that `UITEST_DISABLE_AUDIO_ENGINE=1` is set in launch environment
- Verify TimerTicker is actually running (check state publisher)
- Increase timeout to 10s to rule out timing issues

**AVPlayer Test Failure**:
- Increase timeout to 15s
- Check network connectivity in CI
- Verify episode URL is valid and accessible
- Check simulator audio output settings
- Look for "Failed to load AVAsset" in logs

### "Position should remain stable when paused" failure

**Ticker Test Failure**:
- Tolerance too tight (ticker fires exactly on 0.5s intervals)
- May be residual timer tick (increase tolerance to ±0.2s)
- Check that pause button was actually tapped

**AVPlayer Test Failure**:
- AVPlayer may fire one more callback after pause (normal)
- Increase tolerance to ±1.0s
- Verify AVPlayer.pause() is actually called
- Check for audio session interruptions

### Test hangs on "waiting for mini player"

**Both Modes**:
- Check that Quick Play button tap actually worked
- May need to scroll episode list to make button visible
- Verify episode has valid audioURL
- Check for modal dialogs blocking UI

### AVPlayer tests consistently fail in CI but pass locally

**Common Causes**:
- CI simulator audio session conflicts
- Network firewall blocking media URLs
- CI resource exhaustion (CPU/memory)
- Simulator audio output not configured

**Solutions**:
- Increase all timeouts by 50%
- Use local audio fixture instead of remote URL
- Add retry logic for network errors
- Check CI logs for resource warnings

### Flakiness Metrics

**Acceptable Flakiness**:
- Ticker tests: 0% (should never be flaky)
- AVPlayer tests: <5% (some network variability acceptable)

**Unacceptable Flakiness**:
- Either suite >10% failure rate
- Indicates infrastructure issue or insufficient tolerances

**Remediation Steps**:
1. Run test 10 times locally
2. If passes 10/10, issue is in CI environment
3. If fails locally, increase timeouts/tolerances
4. If still flaky, add test to flakiness investigation issue

## Related Documentation

- **Spec**: `zpod/spec/playback.md` - Playback behavior scenarios
- **Architecture**: `dev-log/03.3.2-avplayer-playback-engine.md` - Implementation details
- **CI Config**: `.github/workflows/ci.yml` - Job configuration
- **Test Summary**: `zpodUITests/TestSummary.md` - All test coverage

## Maintenance Notes

### When to Update This Guide

- New playback test scenarios added
- Timeout values changed
- New failure patterns discovered
- CI configuration changes
- Protocol methods added/changed

### Deprecation Timeline

**Original File**: `zpodUITests/PlaybackPositionUITests.swift`
- **Sprint 1** (Current): Marked deprecated
- **Sprint 2**: Monitor new tests for stability
- **Sprint 3**: Delete original file if new tests stable

## FAQ

**Q: Why do we need two test modes?**
A: Ticker tests validate UI logic (fast, deterministic). AVPlayer tests validate audio integration (real-world, catches AVPlayer-specific bugs).

**Q: Can I run just ticker tests in CI?**
A: No, both suites are blocking. AVPlayer tests are critical for detecting audio integration bugs.

**Q: What if AVPlayer tests are too flaky?**
A: Increase timeouts first. If still flaky >10%, temporarily make non-blocking and open investigation issue.

**Q: Do AVPlayer tests actually play audio?**
A: Yes, but simulator audio may be muted. Tests validate position callbacks, not audio output.

**Q: How do I add a helper method?**
A: Add to `PlaybackPositionTestSupport` protocol extension. Both test classes will automatically inherit it.

**Q: Can I skip AVPlayer tests locally?**
A: Yes, just run ticker tests. But always run both before pushing to ensure no regressions.

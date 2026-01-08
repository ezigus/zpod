// PlaybackPositionAVPlayerTests.swift
//
// UI tests for playback position using the AVPlayer engine (real audio).
//
// **Issue**: 03.3.2.3 - Playback AVPlayer Test Suite
// **Mode**: AVPlayer (production mode, real audio streaming)
// **Spec**: `zpod/spec/playback.md` - Core Playback Behavior
//
// These tests validate position UI updates with actual AVPlayer integration.
// Position updates come from AVPlayer's periodic time observer, not a simulated ticker.
// Longer execution (~20-30 seconds per test), validates real audio pipeline.
//
// **CI Note**: These tests are BLOCKING. Failures indicate AVPlayer integration issues
// that would affect production users.
//
// **CI Job**: UITests-PlaybackAVPlayer

import OSLog
import XCTest

/// UI tests for playback position using the AVPlayer engine (real audio).
///
/// These tests validate the full audio pipeline integration:
/// AVPlayer → EnhancedEpisodePlayer → UI
///
/// **Critical Difference from Ticker Tests**:
/// - Position updates come from AVPlayer's periodic time observer
/// - Longer timeouts account for buffering and network latency
/// - Tolerances increased for real-time playback jitter
/// - Validates production audio path end-to-end
final class PlaybackPositionAVPlayerTests: XCTestCase, PlaybackPositionTestSupport {

    nonisolated(unsafe) var app: XCUIApplication!
    static let logger = Logger(subsystem: "us.zig.zpod", category: "PlaybackPositionAVPlayerTests")

    // MARK: - AVPlayer-Specific Timeouts

    /// Longer timeout for AVPlayer operations (buffering, network latency)
    private let avplayerTimeout: TimeInterval = 10.0

    override func setUpWithError() throws {
        continueAfterFailure = false
        disableWaitingForIdleIfNeeded()
        validateTestAudioExists()
    }

    override func tearDownWithError() throws {
        cleanupAudioLaunchEnvironment()
        app = nil
    }

    @MainActor
    private func launchApp(
        environmentOverrides: [String: String] = [:],
        audioVariant: String = "long"
    ) {
        let audioEnv = audioLaunchEnvironment()

        var env = audioEnv
        env["UITEST_POSITION_DEBUG"] = "1"
        env["UITEST_DEBUG_AUDIO"] = "1"
        env["UITEST_INITIAL_TAB"] = "player"
        env["UITEST_AUDIO_VARIANT"] = audioVariant

        environmentOverrides.forEach { key, value in
            env[key] = value
        }

        app = launchWithPlaybackMode(.avplayer, environmentOverrides: env)
    }

    // MARK: - Test 1: Position Advancement

    /// **Spec**: Timeline Advancement During Playback (lines 62-68)
    /// **Critical**: Validates AVPlayer position callbacks flow to UI.
    ///
    /// **Given**: An episode is playing with real AVPlayer
    /// **When**: Time passes during playback
    /// **Then**: Progress slider position advances
    ///
    /// Unlike ticker mode, position updates come from AVPlayer's periodic time observer.
    /// This test verifies the full integration: AVPlayer → EnhancedEpisodePlayer → UI.
    @MainActor
    func testExpandedPlayerProgressAdvancesDuringPlayback() throws {
        // Given: Episode is playing with real AVPlayer
        launchApp()
        guard startPlaybackFromPlayerTab() else {
            XCTFail("Failed to start playback")
            return
        }

        guard expandPlayer() else {
            XCTFail("Failed to expand player")
            return
        }

        // AVPlayer may need time to buffer and start streaming
        let initialValue = getSliderValue()
        XCTAssertNotNil(initialValue, "Progress slider should have an initial value")
        let initialPosition = extractCurrentPosition(from: initialValue)

        // When: Wait for position to advance (AVPlayer updates every 0.5s)
        // Use longer timeout for AVPlayer (buffering + network latency)
        guard let updatedValue = waitForPositionAdvancement(beyond: initialValue, timeout: avplayerTimeout) else {
            recordAudioDebugOverlay("position advancement timeout")
            XCTFail("Progress slider should have advanced with AVPlayer after \(avplayerTimeout)s")
            return
        }

        // Then: Position should advance (validates AVPlayer → UI pipeline)
        let updatedPosition = extractCurrentPosition(from: updatedValue)

        guard let initial = initialPosition, let updated = updatedPosition else {
            XCTFail("Could not parse position values - initial: \(String(describing: initialValue)), updated: \(updatedValue)")
            return
        }

        XCTAssertGreaterThan(updated, initial,
            "AVPlayer position should advance from \(initial)s to \(updated)s")
        // More tolerant assertion for real-time playback
        XCTAssertGreaterThanOrEqual(updated - initial, 0.5,
            "AVPlayer should advance at least 0.5s (one update cycle)")
    }

    // MARK: - Test 2: Pause Stops Position

    /// **Spec**: Pausing Playback (lines 69-75)
    /// **Critical**: Validates AVPlayer.pause() stops position updates.
    ///
    /// **Given**: An episode is playing with advancing position
    /// **When**: User pauses playback
    /// **Then**: Position stops advancing
    @MainActor
    func testPositionStopsAdvancingWhenPaused() throws {
        launchApp()
        guard startPlaybackFromPlayerTab(), expandPlayer() else {
            XCTFail("Failed to start playback and expand player")
            return
        }

        // Wait for AVPlayer to start streaming and advance position
        let initialValue = getSliderValue()
        guard let advancedValue = waitForPositionAdvancement(beyond: initialValue, timeout: avplayerTimeout) else {
            recordAudioDebugOverlay("pre-pause advancement timeout")
            XCTFail("AVPlayer should have started advancing position before pause test")
            return
        }
        logSliderValue("Advanced before pause", value: advancedValue)

        // When: Pause playback (this calls AVPlayer.pause())
        let pauseButton = app.buttons.matching(identifier: "Expanded Player Pause").firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: adaptiveShortTimeout))
        pauseButton.tap()

        // Verify play button appears (confirms paused state)
        let playButton = app.buttons.matching(identifier: "Expanded Player Play").firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: adaptiveShortTimeout))

        // Then: Position should stop advancing
        let pausedValue = getSliderValue()
        // More tolerant for AVPlayer (may have one more callback after pause)
        let positionStable = verifyPositionStable(at: pausedValue, forDuration: 2.0, tolerance: 0.5)
        XCTAssertTrue(positionStable, "Position should remain stable when paused (within 0.5s)")
    }

    // MARK: - Test 3: Resume Advances Position

    /// **Spec**: Resuming Playback (lines 76-82)
    /// **Critical**: Validates AVPlayer.play() resumes position updates.
    ///
    /// **Given**: An episode is paused
    /// **When**: User resumes playback
    /// **Then**: Position resumes advancing from paused position
    @MainActor
    func testPositionResumesAdvancingAfterPause() throws {
        launchApp()
        guard startPlaybackFromPlayerTab(), expandPlayer() else {
            XCTFail("Failed to start playback and expand player")
            return
        }

        // Pause playback
        let pauseButton = app.buttons.matching(identifier: "Expanded Player Pause").firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: adaptiveShortTimeout))
        pauseButton.tap()

        let playButton = app.buttons.matching(identifier: "Expanded Player Play").firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: adaptiveShortTimeout))

        let pausedValue = getSliderValue()
        let pausedPosition = extractCurrentPosition(from: pausedValue)

        // When: Resume playback (calls AVPlayer.play())
        playButton.tap()
        XCTAssertTrue(pauseButton.waitForExistence(timeout: adaptiveShortTimeout))

        // Then: Position should advance (may need time to resume streaming)
        guard let resumedValue = waitForPositionAdvancement(beyond: pausedValue, timeout: avplayerTimeout) else {
            recordAudioDebugOverlay("resume advancement timeout")
            XCTFail("Position should advance after resuming AVPlayer")
            return
        }

        guard let paused = pausedPosition,
              let resumed = extractCurrentPosition(from: resumedValue) else {
            XCTFail("Could not parse position values - paused: \(String(describing: pausedValue)), resumed: \(resumedValue)")
            return
        }

        XCTAssertGreaterThan(resumed, paused,
            "AVPlayer position should advance from \(paused)s to \(resumed)s after resume")
    }

    // MARK: - Test 4: Seeking Updates Position

    /// **Spec**: Seeking to Position (lines 83-87)
    /// **Critical**: Validates AVPlayer.seek(to:) updates position correctly.
    ///
    /// **Given**: An episode is playing
    /// **When**: User seeks to a new position
    /// **Then**: Position updates immediately and continues advancing
    @MainActor
    func testSeekingUpdatesPositionImmediately() throws {
        logBreadcrumb("testSeekingUpdatesPositionImmediately (AVPlayer): launch app")
        launchApp()
        guard startPlaybackFromPlayerTab(), expandPlayer() else {
            XCTFail("Failed to start playback and expand player")
            return
        }

        guard let initialValue = getSliderValue() else {
            XCTFail("Progress slider value unavailable before seek")
            return
        }
        logSliderValue("initial (AVPlayer)", value: initialValue)
        guard let totalDuration = extractTotalDuration(from: initialValue) else {
            XCTFail("Audio duration unavailable for seek test")
            return
        }
        guard totalDuration > 10.0 else {
            XCTFail("Audio duration too short for seek test (need >10s, got \(totalDuration))")
            return
        }

        // When: Seek to 50% position (calls AVPlayer.seek(to:))
        guard let slider = progressSlider() else {
            XCTFail("Progress slider not found in expanded player")
            return
        }
        XCTAssertTrue(slider.waitForExistence(timeout: adaptiveShortTimeout))

        logBreadcrumb("testSeekingUpdatesPositionImmediately (AVPlayer): seek to target")
        let preSeekValue = getSliderValue()
        let targetNormalized = seekTargetNormalizedPosition(from: preSeekValue)
        slider.adjust(toNormalizedSliderPosition: targetNormalized)

        // Then: Wait for position to change (AVPlayer seek may take time)
        // Use longer stabilization window for AVPlayer seek completion
        let minimumDelta = seekMinimumDelta(from: preSeekValue)
        guard let seekedValue = waitForUIStabilization(
            afterSeekingFrom: preSeekValue,
            timeout: 5.0,  // Longer for AVPlayer seek
            minimumDelta: minimumDelta,
            stabilityWindow: 0.5  // Longer stability window
        ) else {
            recordAudioDebugOverlay("seek did not change slider")
            XCTFail("Slider value should change after AVPlayer seek")
            return
        }
        logSliderValue("seeked (AVPlayer)", value: seekedValue)
        
        // Verify seek landed near 50% mark (within tolerance for network/buffering delays)
        if let seekedPosition = extractCurrentPosition(from: seekedValue),
           let totalDuration = extractTotalDuration(from: seekedValue) {
            let expectedPosition = totalDuration * targetNormalized
            let tolerance = totalDuration * 0.15  // 15% tolerance for AVPlayer seek
            XCTAssertTrue(abs(seekedPosition - expectedPosition) <= tolerance,
                "AVPlayer seek should land near \(expectedPosition)s, got \(seekedPosition)s (tolerance: ±\(tolerance)s)")
        } else {
            XCTFail("Failed to parse seek positions from '\(seekedValue ?? "nil")'")
            return
        }

        // Verify position continues advancing after seek
        guard let finalValue = waitForPositionAdvancement(beyond: seekedValue, timeout: avplayerTimeout) else {
            recordAudioDebugOverlay("post-seek advancement timeout")
            XCTFail("Position should continue advancing after AVPlayer seek")
            return
        }
        logSliderValue("final (AVPlayer)", value: finalValue)
    }

    @MainActor
    private func seekTargetNormalizedPosition(from value: String?) -> Double {
        guard let current = extractCurrentPosition(from: value),
              let total = extractTotalDuration(from: value),
              total > 0 else {
            return 0.5
        }
        let ratio = current / total
        return ratio >= 0.5 ? 0.2 : 0.8
    }

    @MainActor
    private func seekMinimumDelta(from value: String?) -> TimeInterval {
        guard let total = extractTotalDuration(from: value), total > 0 else {
            return 2.0
        }
        return max(2.0, total * 0.1)
    }

    // MARK: - Test 5: Mini-Player State

    /// **Spec**: Timeline Advancement During Playback (Mini-Player)
    /// **Critical**: Validates mini-player UI updates with real AVPlayer state.
    ///
    /// **Given**: An episode is playing
    /// **When**: Mini-player is visible
    /// **Then**: Mini-player reflects playback state
    @MainActor
    func testMiniPlayerReflectsPlaybackState() throws {
        launchApp()
        guard startPlaybackFromPlayerTab() else {
            XCTFail("Failed to start playback")
            return
        }

        // Then: Mini-player should show pause button (AVPlayer is playing)
        let miniPlayer = miniPlayerElement(in: app)
        XCTAssertTrue(miniPlayer.exists)

        let pauseButton = app.buttons.matching(identifier: "Mini Player Pause").firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Mini player should show pause button when AVPlayer is playing")

        // When: Pause via mini-player (calls AVPlayer.pause())
        pauseButton.tap()

        // Then: Play button should appear (AVPlayer is paused)
        let playButton = app.buttons.matching(identifier: "Mini Player Play").firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Mini player should show play button when AVPlayer is paused")
    }

    // MARK: - Test 6: Seek While Paused

    /// **Spec**: Seeking to Position (line 83: "episode is playing or paused")
    /// **Critical**: Validates AVPlayer.seek(to:) works when paused.
    ///
    /// **Given**: An episode is paused with AVPlayer
    /// **When**: User seeks to a new position
    /// **Then**: Position updates via AVPlayer.seek(to:) while paused
    /// **And**: Playback resumes from new position when play is pressed
    @MainActor
    func testSeekingWhilePausedUpdatesPosition() throws {
        // Given: Episode is paused with AVPlayer
        launchApp()
        guard startPlaybackFromPlayerTab(), expandPlayer() else {
            XCTFail("Failed to start playback and expand player")
            return
        }

        // Pause AVPlayer first
        let pauseButton = app.buttons.matching(identifier: "Expanded Player Pause").firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: adaptiveShortTimeout))
        pauseButton.tap()

        let playButton = app.buttons.matching(identifier: "Expanded Player Play").firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Play button should appear after AVPlayer pause")

        // When: Seek to 70% while AVPlayer is paused
        let pausedValue = getSliderValue()
        logSliderValue("paused before seek (AVPlayer)", value: pausedValue)

        guard let slider = progressSlider() else {
            XCTFail("Progress slider not found in expanded player")
            return
        }
        XCTAssertTrue(slider.waitForExistence(timeout: adaptiveShortTimeout))
        slider.adjust(toNormalizedSliderPosition: 0.7)

        // Then: Position should update via AVPlayer.seek(to:) even while paused
        guard let seekedValue = waitForUIStabilization(
            afterSeekingFrom: pausedValue,
            timeout: 5.0,
            minimumDelta: 3.0,
            stabilityWindow: 0.5
        ) else {
            recordAudioDebugOverlay("seek while paused did not change slider")
            XCTFail("Position should update when seeking with AVPlayer while paused")
            return
        }
        logSliderValue("seeked while paused (AVPlayer)", value: seekedValue)

        // Verify still paused (play button still visible)
        XCTAssertTrue(playButton.exists, "Should remain paused after AVPlayer seek")

        // And: Playback should resume from seek position
        playButton.tap()
        guard let resumedValue = waitForPositionAdvancement(beyond: seekedValue, timeout: avplayerTimeout) else {
            recordAudioDebugOverlay("resume after seek advancement timeout")
            XCTFail("Position should advance after seeking while paused and resuming AVPlayer")
            return
        }
        logSliderValue("resumed after seek (AVPlayer)", value: resumedValue)
    }

    // MARK: - Test 7: Missing/Network Errors (Blocked by 03.3.4)

    @MainActor
    func testMissingAudioURLShowsErrorNoRetry() throws {
        throw XCTSkip("Blocked by 03.3.4: error UI/messages not aligned yet")
    }

    @MainActor
    func testNetworkErrorShowsRetryAndRecovers() throws {
        throw XCTSkip("Blocked by 03.3.4: error UI/messages not aligned yet")
    }

    // MARK: - Test 8: Interruption Handling

    /// **Spec**: Audio Interruption Handling
    /// 
    /// **NOTE**: This test is currently skipped due to UI visibility issues with debug controls.
    /// The PlaybackDebugControlsView overlay doesn't appear consistently in the Player tab during
    /// UI tests, preventing interaction with interruption simulation buttons.
    /// 
    /// **TODO**: Investigate alternative approaches:
    /// 1. Move debug controls to a different location (bottom overlay?)
    /// 2. Use notification-based triggering instead of UI buttons
    /// 3. Add integration test that posts notifications directly
    @MainActor
    func testInterruptionPausesAndResumesPlayback() throws {
        throw XCTSkip("Debug controls not accessible in Player tab - needs UI investigation")
        
        /* Original test code preserved for when UI issue is resolved:
        launchApp(environmentOverrides: ["UITEST_PLAYBACK_DEBUG": "1"])

        guard startPlaybackFromPlayerTab() else {
            XCTFail("Failed to start playback from Player tab")
            return
        }

        guard waitForPlayerTabAdvancement(timeout: avplayerTimeout) != nil else {
            XCTFail("Playback should advance before interruption")
            return
        }

        let interruptionBegan = app.buttons.matching(identifier: "Playback.Debug.InterruptionBegan").firstMatch
        guard interruptionBegan.waitForExistence(timeout: adaptiveShortTimeout) else {
            XCTFail("Interruption debug button not found")
            return
        }
        interruptionBegan.tap()

        let playButton = app.buttons.matching(identifier: "Play").firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Playback should pause on interruption")

        let pausedValue = playerTabSliderValue()
        XCTAssertTrue(
            verifyPlayerTabPositionStable(at: pausedValue, forDuration: 1.5, tolerance: 0.5),
            "Position should remain stable during interruption"
        )

        let interruptionEnded = app.buttons.matching(identifier: "Playback.Debug.InterruptionEnded").firstMatch
        guard interruptionEnded.waitForExistence(timeout: adaptiveShortTimeout) else {
            XCTFail("Interruption end debug button not found")
            return
        }
        interruptionEnded.tap()

        let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Playback should resume after interruption ends")

        guard waitForPlayerTabAdvancement(beyond: pausedValue, timeout: avplayerTimeout) != nil else {
            XCTFail("Playback should advance after interruption resumes")
            return
        }
        */
    }

    // MARK: - Test 9: Speed Rate

    @MainActor
    func testPlaybackSpeedChangesPositionRate() throws {
        launchApp()

        guard startPlaybackFromPlayerTab() else {
            XCTFail("Failed to start playback from Player tab")
            return
        }

        guard waitForPlayerTabAdvancement(timeout: avplayerTimeout) != nil else {
            XCTFail("Playback should advance before speed measurement")
            return
        }

        guard let baselineStart = playerTabSliderValue(),
              let baselineStartPosition = extractCurrentPosition(from: baselineStart) else {
            XCTFail("Unable to read baseline position")
            return
        }

        let baselineStartTime = Date()
        _ = waitUntil(timeout: 2.4, pollInterval: 0.1, description: "baseline window") {
            Date().timeIntervalSince(baselineStartTime) >= 2.0
        }

        guard let baselineEnd = playerTabSliderValue(),
              let baselineEndPosition = extractCurrentPosition(from: baselineEnd) else {
            XCTFail("Unable to read baseline end position")
            return
        }

        let baselineDelta = baselineEndPosition - baselineStartPosition
        XCTAssertGreaterThan(baselineDelta, 0.5,
            "Baseline playback should advance before speed change")

        let speedControl = app.buttons.matching(identifier: "Speed Control").firstMatch
        guard speedControl.waitForExistence(timeout: adaptiveShortTimeout) else {
            XCTFail("Speed control not found")
            return
        }
        speedControl.tap()

        let speedOption = app.buttons.matching(identifier: "PlaybackSpeed.Option.2.0x").firstMatch
        guard speedOption.waitForExistence(timeout: adaptiveShortTimeout) else {
            XCTFail("Speed option 2.0x not found")
            return
        }
        speedOption.tap()

        guard let fastStart = playerTabSliderValue(),
              let fastStartPosition = extractCurrentPosition(from: fastStart) else {
            XCTFail("Unable to read position after speed change")
            return
        }

        let fastStartTime = Date()
        _ = waitUntil(timeout: 2.4, pollInterval: 0.1, description: "fast window") {
            Date().timeIntervalSince(fastStartTime) >= 2.0
        }

        guard let fastEnd = playerTabSliderValue(),
              let fastEndPosition = extractCurrentPosition(from: fastEnd) else {
            XCTFail("Unable to read fast end position")
            return
        }

        let fastDelta = fastEndPosition - fastStartPosition
        XCTAssertGreaterThan(
            fastDelta,
            baselineDelta * 1.4,
            "Playback should advance faster at 2.0x (baseline \(baselineDelta)s, fast \(fastDelta)s)"
        )
    }

    // MARK: - Helpers

    @MainActor
    private func playerTabSliderValue() -> String? {
        let slider = app.sliders.matching(identifier: "Progress Slider").firstMatch
        guard slider.waitForExistence(timeout: adaptiveShortTimeout) else {
            return nil
        }
        return slider.value as? String
    }

    @MainActor
    private func waitForPlayerTabAdvancement(
        beyond initialValue: String? = nil,
        timeout: TimeInterval
    ) -> String? {
        let slider = app.sliders.matching(identifier: "Progress Slider").firstMatch
        guard slider.waitForExistence(timeout: adaptiveShortTimeout) else {
            return nil
        }

        let initialPosition = extractCurrentPosition(from: initialValue) ?? 0
        var observedValue: String?

        let advanced = waitUntil(timeout: timeout, pollInterval: 0.1, description: "player tab advancement") {
            guard let currentValue = slider.value as? String,
                  let currentPosition = self.extractCurrentPosition(from: currentValue) else {
                return false
            }
            if currentPosition > initialPosition + 1.0 {
                let firstValue = currentValue
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                guard let secondValue = slider.value as? String else {
                    return false
                }
                if secondValue == firstValue {
                    observedValue = firstValue
                    return true
                }
            }
            return false
        }

        return advanced ? observedValue : nil
    }

    @MainActor
    private func verifyPlayerTabPositionStable(
        at expectedValue: String?,
        forDuration: TimeInterval,
        tolerance: TimeInterval
    ) -> Bool {
        let slider = app.sliders.matching(identifier: "Progress Slider").firstMatch
        guard slider.waitForExistence(timeout: adaptiveShortTimeout) else {
            return false
        }
        guard let expectedPosition = extractCurrentPosition(from: expectedValue) else {
            return false
        }

        let deadline = Date().addingTimeInterval(forDuration)
        var observedWithinTolerance = false

        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            guard let currentValue = slider.value as? String,
                  let currentPosition = extractCurrentPosition(from: currentValue) else {
                continue
            }

            let deviation = abs(currentPosition - expectedPosition)
            if deviation > tolerance {
                return false
            }

            observedWithinTolerance = true
        }

        return observedWithinTolerance
    }
}

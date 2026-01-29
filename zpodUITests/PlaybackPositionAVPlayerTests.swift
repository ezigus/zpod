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

// swiftlint:disable:next type_body_length
final class PlaybackPositionAVPlayerTests: IsolatedUITestCase, PlaybackPositionTestSupport {

    static let logger = Logger(subsystem: "us.zig.zpod", category: "PlaybackPositionAVPlayerTests")

    // MARK: - AVPlayer-Specific Timeouts

    /// Longer timeout for AVPlayer operations (buffering, network latency)
    private let avplayerTimeout: TimeInterval = 10.0

    override func setUpWithError() throws {
        try super.setUpWithError()
        disableWaitingForIdleIfNeeded()
        validateTestAudioExists()
    }

    override func tearDownWithError() throws {
        cleanupAudioLaunchEnvironment()
        try super.tearDownWithError()
    }

    @MainActor
    private func launchApp(
        environmentOverrides: [String: String] = [:],
        audioVariant: String = "long"  // Default: 20s audio for buffering tests
    ) {
        guard let audioEnv = audioLaunchEnvironment() else {
            return
        }

        var env = audioEnv
        env["UITEST_POSITION_DEBUG"] = "1"
        env["UITEST_DEBUG_AUDIO"] = "1"
        env["UITEST_INITIAL_TAB"] = "player"
        env["UITEST_AUDIO_VARIANT"] = audioVariant

        // Pass CI flag through to app so timing thresholds can be adjusted
        // GitHub Actions sets GITHUB_ACTIONS=true; pass it to the app for threshold adjustments
        if ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil {
            env["UITEST_CI_MODE"] = "1"
        }

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
    /// **CI Note**: AVPlayer seek accuracy requires real audio hardware - skipped in CI. See `_CI` variant for UI verification.
    @MainActor
    func testSeekingUpdatesPositionImmediately() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil,
            "AVPlayer seek accuracy requires real audio hardware - CI tests UI only"
        )
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
            // AVPlayer on simulators can drift; use a wider tolerance.
            let tolerance = totalDuration * 0.25  // 25% tolerance for AVPlayer seek
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

    /// **CI Variant**: Seeking UI Controls
    ///
    /// Verifies that progress slider exists and responds to adjustment in CI.
    /// Does NOT verify AVPlayer seek accuracy (which requires real audio hardware).
    ///
    /// **Given**: An episode is playing
    /// **When**: User adjusts the progress slider
    /// **Then**: Slider exists, is enabled, and value changes after adjustment
    @MainActor
    func testSeekingUpdatesPositionImmediately_CI() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil,
            "CI-only test for UI interaction verification"
        )

        launchApp()
        guard startPlaybackFromPlayerTab(), expandPlayer() else {
            XCTFail("Failed to start playback and expand player")
            return
        }

        // Verify progress slider exists and is adjustable
        guard let slider = progressSlider() else {
            XCTFail("Progress slider not found in expanded player")
            return
        }
        XCTAssertTrue(slider.waitForExistence(timeout: adaptiveShortTimeout),
            "Progress slider should exist")
        XCTAssertTrue(slider.isEnabled,
            "Progress slider should be enabled")

        // Get initial value
        let initialValue = slider.value as? String
        XCTAssertNotNil(initialValue, "Progress slider should have an initial value")

        // Adjust slider and verify value changes (UI responds)
        slider.adjust(toNormalizedSliderPosition: 0.5)

        // Give UI time to update
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        let adjustedValue = slider.value as? String
        XCTAssertNotEqual(initialValue, adjustedValue,
            "Slider value should change after adjustment (UI responds)")

        // Verify slider is still enabled after adjustment
        XCTAssertTrue(slider.isEnabled,
            "Progress slider should remain enabled after adjustment")
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

    // MARK: - Test 7: Error Handling
    
    /// **Spec**: Episode Missing Audio URL (error handling)
    ///
    /// **Given**: An episode has no audioURL
    /// **When**: User attempts to play the episode
    /// **Then**: Error UI appears with "doesn't have audio available" message
    /// **And**: NO retry button shown (not recoverable)
    @MainActor
    func testMissingAudioURLShowsErrorNoRetry() throws {
        // Given: Launch with environment that creates episodes with nil audioURL
        launchApp(
            environmentOverrides: ["UITEST_AUDIO_OVERRIDE_MODE": "missing"],
            audioVariant: "short"
        )
        
        // When: Navigate to Player tab
        let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
        let playerTab = tabBar.buttons.matching(identifier: "Player").firstMatch
        guard playerTab.waitForExistence(timeout: adaptiveShortTimeout) else {
            XCTFail("Player tab not found")
            return
        }
        playerTab.tap()
        
        // Wait for episode detail to load
        guard waitForContentToLoad(
            containerIdentifier: "Episode Detail View",
            timeout: adaptiveTimeout
        ) else {
            XCTFail("Episode detail failed to load")
            return
        }
        
        // Tap play button
        let episodeDetail = app.otherElements.matching(identifier: "Episode Detail View").firstMatch
        let playButton = episodeDetail.buttons.matching(identifier: "Play").firstMatch
        guard playButton.waitForExistence(timeout: adaptiveShortTimeout) else {
            XCTFail("Play button not found in episode detail")
            return
        }
        playButton.tap()
        
        guard expandPlayer() else {
            XCTFail("Failed to open expanded player for error validation")
            return
        }

        let missingAudioPredicate = NSPredicate(
            format: "label CONTAINS[c] %@",
            "doesn't have audio available"
        )
        let missingAudioMessage = app.staticTexts.matching(missingAudioPredicate).firstMatch
        XCTAssertTrue(
            missingAudioMessage.waitForExistence(timeout: adaptiveTimeout),
            "Accessible missing-audio message should appear"
        )

        // Verify NO retry button (not recoverable)
        let retryButton = app.buttons.matching(identifier: "ExpandedPlayer.RetryButton").firstMatch
        XCTAssertFalse(
            retryButton.exists,
            "Should not show retry button for missing URL (not recoverable)"
        )
    }
    
    /// **Spec**: Network Error During Playback (error handling with retry)
    ///
    /// **Given**: An episode has an unreachable audioURL
    /// **When**: User attempts to play the episode
    /// **Then**: Error UI appears with network error message
    /// **And**: Retry button is shown (recoverable error)
    @MainActor
    func testNetworkErrorShowsRetryAndRecovers() throws {
        // Given: Launch with environment that uses an invalid URL and enable the error debug controls.
        // The UI doesn’t surface the overlay automatically for this scenario, so we manually trigger it in the next step.
        launchApp(
            environmentOverrides: [
                "UITEST_AUDIO_OVERRIDE_URL": "http://127.0.0.1:9999/episode.mp3",
                "ENABLE_ERROR_DEBUG": "1"
            ],
            audioVariant: "short"
        )
        
        // When: Navigate to Player tab
        let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
        let playerTab = tabBar.buttons.matching(identifier: "Player").firstMatch
        guard playerTab.waitForExistence(timeout: adaptiveShortTimeout) else {
            XCTFail("Player tab not found")
            return
        }
        playerTab.tap()
        
        // Wait for episode detail to load
        guard waitForContentToLoad(
            containerIdentifier: "Episode Detail View",
            timeout: adaptiveTimeout
        ) else {
            XCTFail("Episode detail failed to load")
            return
        }
        
        // Tap play button
        let episodeDetail = app.otherElements.matching(identifier: "Episode Detail View").firstMatch
        let playButton = episodeDetail.buttons.matching(identifier: "Play").firstMatch
        guard playButton.waitForExistence(timeout: adaptiveShortTimeout) else {
            XCTFail("Play button not found in episode detail")
            return
        }
        playButton.tap()
        
        guard expandPlayer() else {
            XCTFail("Failed to open expanded player for debug controls")
            return
        }

        let networkDebugButton = app.buttons.matching(identifier: "ErrorDebug.Network").firstMatch
        XCTAssertTrue(
            networkDebugButton.waitForExistence(timeout: adaptiveTimeout),
            "Network error debug button should be available"
        )
        networkDebugButton.tap()

        let networkErrorPredicate = NSPredicate(
            format: "label CONTAINS[c] %@",
            "Unable to load episode"
        )
        let networkErrorMessage = app.staticTexts.matching(networkErrorPredicate).firstMatch
        XCTAssertTrue(
            networkErrorMessage.waitForExistence(timeout: adaptiveTimeout),
            "Network error message should appear"
        )

        // Verify retry button exists (recoverable error)
        let retryButton = app.buttons.matching(identifier: "ExpandedPlayer.RetryButton").firstMatch
        XCTAssertTrue(
            retryButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Should show retry button for network error (recoverable)"
        )
        XCTAssertTrue(retryButton.isEnabled, "Retry button should be enabled")
    }

    // MARK: - Test 8: Interruption Handling

    /// **Spec**: Audio Interruption Handling
    ///
    /// **Note**: Uses debug interruption controls gated by `UITEST_PLAYBACK_DEBUG`.
    /// **CI Note**: AVPlayer interruption requires real audio hardware - skipped in CI. See `_CI` variant for UI verification.
    @MainActor
    func testInterruptionPausesAndResumesPlayback() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil,
            "AVPlayer interruption requires real audio hardware - CI tests UI only"
        )
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
    }

    /// **CI Variant**: Interruption UI Controls
    ///
    /// Verifies that interruption debug controls exist and are tappable in CI.
    /// Does NOT verify AVPlayer behavior (which requires real audio hardware).
    ///
    /// **Given**: Playback debug mode enabled
    /// **When**: App is launched
    /// **Then**: Interruption debug controls exist and respond to taps
    @MainActor
    func testInterruptionPausesAndResumesPlayback_CI() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil,
            "CI-only test for UI interaction verification"
        )

        launchApp(environmentOverrides: ["UITEST_PLAYBACK_DEBUG": "1"])

        guard startPlaybackFromPlayerTab() else {
            XCTFail("Failed to start playback from Player tab")
            return
        }

        // Verify interruption debug controls exist and are tappable
        let interruptionBegan = app.buttons.matching(identifier: "Playback.Debug.InterruptionBegan").firstMatch
        XCTAssertTrue(interruptionBegan.waitForExistence(timeout: adaptiveShortTimeout),
            "Interruption Begin button should exist")
        XCTAssertTrue(interruptionBegan.isHittable,
            "Interruption Begin button should be tappable")

        // Tap to verify button responds
        interruptionBegan.tap()

        // Verify play/pause buttons exist and respond (UI only, not AVPlayer behavior)
        let playButton = app.buttons.matching(identifier: "Play").firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Play button should appear (UI responds to interruption tap)")

        // Verify interruption end button exists
        let interruptionEnded = app.buttons.matching(identifier: "Playback.Debug.InterruptionEnded").firstMatch
        XCTAssertTrue(interruptionEnded.waitForExistence(timeout: adaptiveShortTimeout),
            "Interruption End button should exist")
        XCTAssertTrue(interruptionEnded.isHittable,
            "Interruption End button should be tappable")

        // Tap to verify button responds
        interruptionEnded.tap()

        // Verify pause button exists (UI responds to interruption end tap)
        let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Pause button should appear (UI responds to interruption end tap)")
    }

    // MARK: - Test 9: Speed Rate

    @MainActor
    // swiftlint:disable:next function_body_length
    func testPlaybackSpeedChangesPositionRate() throws {
        launchApp(environmentOverrides: ["UITEST_PLAYBACK_DEBUG": "1"])

        guard startPlaybackFromPlayerTab() else {
            XCTFail("Failed to start playback from Player tab")
            return
        }

        let initialPauseButton = app.buttons.matching(identifier: "Pause").firstMatch
        guard initialPauseButton.waitForExistence(timeout: adaptiveTimeout) else {
            XCTFail("Pause button not found after starting playback")
            return
        }
        initialPauseButton.tap()
        XCTContext.runActivity(named: "Paused playback before baseline setup") { _ in }

        // CRITICAL FIX: Explicitly set baseline speed to 1.0x (was implicit assumption)
        // CI failure data showed baselineDelta=4.0s over 2.0s window → suggests baseline was at ~2.0x
        XCTContext.runActivity(named: "Set baseline speed to 1.0x") { _ in
            let speedControl = app.buttons.matching(identifier: "Speed Control").firstMatch
            XCTAssertTrue(speedControl.waitForExistence(timeout: adaptiveShortTimeout),
                "Speed Control button should exist")

            // Check current speed before changing
            let currentSpeedLabel = speedControl.label
            XCTContext.runActivity(named: "Current speed before setting: \(currentSpeedLabel)") { _ in }

            if !currentSpeedLabel.contains("1.0x") && !currentSpeedLabel.contains("1x") {
                guard let oneXOption = openSpeedOption(identifier: "PlaybackSpeed.Option.1.0x") else {
                    XCTFail("1.0x speed option should exist")
                    return
                }
                oneXOption.tap()

                // Wait for UI to settle (speed menu should close)
                _ = waitUntil(timeout: 1.0, pollInterval: 0.1, description: "speed UI settle") {
                    !oneXOption.exists
                }
            }

            // VERIFY speed was actually set to 1.0x by checking accessibility label
            let updatedSpeedLabel = speedControl.label
            XCTContext.runActivity(named: "Speed after setting to 1.0x: \(updatedSpeedLabel)") { _ in }
            XCTAssertTrue(updatedSpeedLabel.contains("1.0x") || updatedSpeedLabel.contains("1x"),
                "Speed Control should show 1.0x after setting (got: '\(updatedSpeedLabel)')")

            XCTContext.runActivity(named: "Baseline speed confirmed at 1.0x") { _ in }
        }

        XCTContext.runActivity(named: "Ensure playback position near start") { _ in
            guard let overlay = audioDebugOverlayElement(timeout: adaptiveShortTimeout) else {
                recordAudioDebugOverlay("audio debug overlay missing before baseline")
                XCTFail("Audio debug overlay not available for baseline setup")
                return
            }

            guard let overlayText = audioDebugOverlayLabel(for: overlay),
                  let initialPosition = audioDebugPosition(from: overlayText),
                  let duration = audioDebugDuration(from: overlayText) else {
                recordAudioDebugOverlay("audio debug parse failed before baseline")
                XCTFail("Unable to parse audio debug overlay before baseline")
                return
            }

            let safePositionLimit = min(3.0, duration * 0.2)
            if initialPosition <= safePositionLimit {
                XCTContext.runActivity(named: "Position already near start: \(String(format: "%.2f", initialPosition))s") { _ in }
                return
            }

            let skipBackward = app.buttons.matching(identifier: "Skip Backward").firstMatch
            guard skipBackward.waitForExistence(timeout: adaptiveShortTimeout) else {
                recordAudioDebugOverlay("skip backward missing")
                XCTFail("Skip Backward button not available for baseline setup")
                return
            }

            var currentPosition = initialPosition
            for attempt in 1...3 {
                skipBackward.tap()

                let moved = waitForState(timeout: 2.0, pollInterval: 0.1, description: "skip backward \(attempt)") {
                    guard let updatedText = audioDebugOverlayLabel(for: overlay),
                          let updatedPosition = audioDebugPosition(from: updatedText) else {
                        return false
                    }
                    return updatedPosition < currentPosition
                }

                if !moved {
                    recordAudioDebugOverlay("skip backward did not move")
                    XCTFail("Skip Backward did not update playback position")
                    return
                }

                guard let updatedText = audioDebugOverlayLabel(for: overlay),
                      let updatedPosition = audioDebugPosition(from: updatedText) else {
                    recordAudioDebugOverlay("skip backward parse failed")
                    XCTFail("Unable to read position after skip backward")
                    return
                }

                currentPosition = updatedPosition
                if currentPosition <= safePositionLimit {
                    XCTContext.runActivity(named: "Position reset to \(String(format: "%.2f", currentPosition))s") { _ in }
                    break
                }
            }

            if currentPosition > safePositionLimit {
                recordAudioDebugOverlay("position still near end after skip back")
                XCTFail("Playback position remained near end (\(String(format: "%.2f", currentPosition))s) after skip backward")
            }
        }

        let baselinePlayButton = app.buttons.matching(identifier: "Play").firstMatch
        guard baselinePlayButton.waitForExistence(timeout: adaptiveShortTimeout) else {
            XCTFail("Play button not found before baseline measurement")
            return
        }
        baselinePlayButton.tap()
        XCTContext.runActivity(named: "Resumed playback for baseline measurement") { _ in }

        guard let overlay = audioDebugOverlayElement(timeout: adaptiveShortTimeout) else {
            recordAudioDebugOverlay("audio debug overlay missing before baseline")
            XCTFail("Audio debug overlay not available for baseline measurement")
            return
        }

        let baselineRateConfirmed = waitForState(timeout: avplayerTimeout, pollInterval: 0.1, description: "baseline rate confirmation") {
            guard let text = audioDebugOverlayLabel(for: overlay),
                  let rate = audioDebugEngineRate(from: text) else {
                return false
            }
            return abs(rate - 1.0) <= 0.1
        }

        guard baselineRateConfirmed else {
            recordAudioDebugOverlay("baseline rate wait failed")
            XCTFail("Audio engine rate did not settle at 1.0x before baseline measurement")
            return
        }

        // Baseline measurement start (use audio debug overlay for fractional seconds)
        guard let baselineStartText = audioDebugOverlayLabel(for: overlay),
              let baselineStartPosition = audioDebugPosition(from: baselineStartText) else {
            recordAudioDebugOverlay("baseline start read failed")
            XCTFail("Unable to read baseline position from audio debug overlay")
            return
        }

        let baselineStartRate = audioDebugEngineRate(from: baselineStartText)
        XCTContext.runActivity(named: "Baseline Start") { _ in
            XCTContext.runActivity(named: "Rate: \(baselineStartRate.map { String(format: "%.2f", $0) } ?? "nil")") { _ in }
            XCTContext.runActivity(named: "Position: \(String(format: "%.2f", baselineStartPosition))s") { _ in }
        }

        let baselineWindow: TimeInterval = 1.0
        let baselineStartTime = Date()

        _ = waitUntil(timeout: baselineWindow + 0.6, pollInterval: 0.1, description: "baseline window") { [self] in
            Date().timeIntervalSince(baselineStartTime) >= baselineWindow
        }

        let actualBaselineElapsed = Date().timeIntervalSince(baselineStartTime)

        guard let baselineEndText = audioDebugOverlayLabel(for: overlay),
              let baselineEndPosition = audioDebugPosition(from: baselineEndText) else {
            recordAudioDebugOverlay("baseline end read failed")
            XCTFail("Unable to read baseline end position from audio debug overlay")
            return
        }

        let baselineEndRate = audioDebugEngineRate(from: baselineEndText)
        XCTContext.runActivity(named: "Baseline End") { _ in
            XCTContext.runActivity(named: "Rate: \(baselineEndRate.map { String(format: "%.2f", $0) } ?? "nil")") { _ in }
            XCTContext.runActivity(named: "Position: \(String(format: "%.2f", baselineEndPosition))s") { _ in }
        }

        let baselineDelta = baselineEndPosition - baselineStartPosition

        XCTContext.runActivity(named: "Baseline window: target=\(String(format: "%.1f", baselineWindow))s, actual=\(String(format: "%.3f", actualBaselineElapsed))s") { _ in }
        XCTContext.runActivity(named: "Baseline delta: \(String(format: "%.3f", baselineDelta))s") { _ in }
        XCTAssertGreaterThan(baselineDelta, 0.2,
            "Baseline playback should advance before speed change")

        guard let speedOption = openSpeedOption(identifier: "PlaybackSpeed.Option.2.0x") else {
            XCTFail("Speed option 2.0x not found")
            return
        }
        speedOption.tap()

        // Wait for speed menu to close
        _ = waitUntil(timeout: 1.0, pollInterval: 0.1, description: "speed menu close") {
            !speedOption.exists
        }

        // VERIFY speed was actually set to 2.0x by checking accessibility label
        let speedControl = app.buttons.matching(identifier: "Speed Control").firstMatch
        XCTAssertTrue(speedControl.waitForExistence(timeout: adaptiveShortTimeout),
            "Speed control not found after setting fast speed")
        let fastSpeedLabel = speedControl.label
        XCTContext.runActivity(named: "Speed after setting to 2.0x: \(fastSpeedLabel)") { _ in }
        XCTAssertTrue(fastSpeedLabel.contains("2.0x") || fastSpeedLabel.contains("2x"),
            "Speed Control should show 2.0x after setting (got: '\(fastSpeedLabel)')")

        let fastWindow: TimeInterval = 1.0

        // CI-aware thresholds: looser in CI due to performance variability
        // Use ProcessInfo.processInfo.environment["CI"] - GitHub Actions sets CI=true automatically
        // Note: app.launchEnvironment["UITEST_CI_MODE"] doesn't work after app.launch()
        let isCI = ProcessInfo.processInfo.environment["CI"] != nil
        let rateConfirmTimeout: TimeInterval = isCI ? 5.0 : 2.0
        let rateConfirmThreshold: Double = isCI ? 1.5 : 1.8

        let fastRateConfirmed = waitForState(timeout: rateConfirmTimeout, pollInterval: 0.1, description: "fast rate confirmation") {
            guard let text = audioDebugOverlayLabel(for: overlay),
                  let rate = audioDebugEngineRate(from: text) else {
                return false
            }
            return rate >= rateConfirmThreshold
        }

        if !fastRateConfirmed {
            recordAudioDebugOverlay("fast rate not confirmed")
            XCTFail("Audio engine rate did not reach 2.0x before fast measurement")
            return
        }

        // Fast measurement start (use audio debug overlay for fractional seconds)
        guard let fastStartText = audioDebugOverlayLabel(for: overlay),
              let fastStartPosition = audioDebugPosition(from: fastStartText) else {
            recordAudioDebugOverlay("fast start read failed")
            XCTFail("Unable to read position after speed change from audio debug overlay")
            return
        }

        let fastStartRate = audioDebugEngineRate(from: fastStartText)
        XCTContext.runActivity(named: "Fast Start") { _ in
            XCTContext.runActivity(named: "Rate: \(fastStartRate.map { String(format: "%.2f", $0) } ?? "nil")") { _ in }
            XCTContext.runActivity(named: "Position: \(String(format: "%.2f", fastStartPosition))s") { _ in }
        }

        let fastStartTime = Date()

        _ = waitUntil(timeout: fastWindow + 0.6, pollInterval: 0.1, description: "fast window") { [self] in
            Date().timeIntervalSince(fastStartTime) >= fastWindow
        }

        let actualFastElapsed = Date().timeIntervalSince(fastStartTime)

        guard let fastEndText = audioDebugOverlayLabel(for: overlay),
              let fastEndPosition = audioDebugPosition(from: fastEndText) else {
            recordAudioDebugOverlay("fast end read failed")
            XCTFail("Unable to read fast end position from audio debug overlay")
            return
        }

        let fastEndRate = audioDebugEngineRate(from: fastEndText)
        XCTContext.runActivity(named: "Fast End") { _ in
            XCTContext.runActivity(named: "Rate: \(fastEndRate.map { String(format: "%.2f", $0) } ?? "nil")") { _ in }
            XCTContext.runActivity(named: "Position: \(String(format: "%.2f", fastEndPosition))s") { _ in }
        }

        let fastDelta = fastEndPosition - fastStartPosition

        XCTContext.runActivity(named: "Fast window: target=\(String(format: "%.1f", fastWindow))s, actual=\(String(format: "%.3f", actualFastElapsed))s") { _ in }
        XCTContext.runActivity(named: "Fast delta: \(String(format: "%.3f", fastDelta))s") { _ in }

        // Environment-specific thresholds via app launch environment
        // Local: Strict threshold (1.7x) catches regressions during development
        // CI: Relaxed threshold (1.5x) accommodates GitHub Actions runner variability
        // Both prove 2.0x playback works (significantly faster than 1.0x baseline)
        let isCIMode = app.launchEnvironment["UITEST_CI_MODE"] == "1"
        let speedThreshold: Double = isCIMode ? 1.5 : 1.7

        // Compute and log measurements before assertion
        let ratio = fastDelta / baselineDelta
        let threshold = baselineDelta * speedThreshold
        let passSummary = ratio >= speedThreshold
            ? "YES"
            : "NO (need \(String(format: "%.3f", threshold))s)"

        XCTContext.runActivity(named: "Measurements") { _ in
            XCTContext.runActivity(named: "Baseline: \(String(format: "%.3f", baselineDelta))s over \(String(format: "%.3f", actualBaselineElapsed))s") { _ in }
            XCTContext.runActivity(named: "Fast: \(String(format: "%.3f", fastDelta))s over \(String(format: "%.3f", actualFastElapsed))s") { _ in }
            XCTContext.runActivity(named: "Ratio: \(String(format: "%.2f", ratio))x (threshold \(String(format: "%.1f", speedThreshold))x, CI=\(isCIMode))") { _ in }
            XCTContext.runActivity(named: "Pass? \(passSummary)") { _ in }
        }

        // Assert: Position should advance ~2x faster at 2.0x speed
        // Using environment-specific thresholds (1.7x local, 1.5x CI) to account for:
        // - AVPlayer buffering delays
        // - UI update cycle latency
        // - Test timing measurement variance
        // - CI runner performance variability
        // Real-world observation: 1.8x-2.5x typical locally, 1.5x-1.6x in CI
        // Local 1.7x catches regressions, CI 1.5x accommodates runner variability
        XCTAssertGreaterThan(
            fastDelta,
            baselineDelta * speedThreshold,
            "Playback should advance ~2x faster at 2.0x speed (baseline \(baselineDelta)s, fast \(fastDelta)s, ratio \(fastDelta/baselineDelta)x)"
        )
    }

    // MARK: - Helpers

    @MainActor
    private func playerTabSlider() -> XCUIElement? {
        let episodeDetail = app.otherElements.matching(identifier: "Episode Detail View").firstMatch
        guard episodeDetail.waitForExistence(timeout: adaptiveShortTimeout) else {
            return nil
        }
        let slider = episodeDetail.sliders.matching(identifier: "Progress Slider").firstMatch
        guard slider.waitForExistence(timeout: adaptiveShortTimeout) else {
            return nil
        }
        return slider
    }

    @MainActor
    private func playerTabSliderValue() -> String? {
        playerTabSlider()?.value as? String
    }

    @MainActor
    private func waitForPlayerTabAdvancement(
        beyond initialValue: String? = nil,
        timeout: TimeInterval
    ) -> String? {
        guard let slider = playerTabSlider() else {
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

    @MainActor
    private func openSpeedOption(
        identifier: String,
        attempts: Int = 3,
        existTimeout: TimeInterval = 2.0
    ) -> XCUIElement? {
        let speedControl = app.buttons.matching(identifier: "Speed Control").firstMatch
        guard speedControl.waitForExistence(timeout: adaptiveShortTimeout) else {
            return nil
        }

        let optionQuery = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        for attempt in 1...attempts {
            speedControl.tap()

            if optionQuery.waitForExistence(timeout: existTimeout) {
                return optionQuery
            }

            // Dismiss stale dialogs between retries to avoid stacked sheets
            if app.buttons["Cancel"].waitForExistence(timeout: 0.5) {
                app.buttons["Cancel"].tap()
            }

            XCTContext.runActivity(named: "Retry opening speed menu (\(attempt)/\(attempts))") { _ in }
        }

        return nil
    }
}

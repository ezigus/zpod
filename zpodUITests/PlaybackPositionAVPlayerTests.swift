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

    /// More tolerant position delta for real-time playback jitter
    private let avplayerPositionTolerance: TimeInterval = 2.0

    override func setUpWithError() throws {
        continueAfterFailure = false
        disableWaitingForIdleIfNeeded()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    private func launchApp() {
        // Launch WITHOUT UITEST_DISABLE_AUDIO_ENGINE to use real AVPlayer
        app = launchConfiguredApp(
            environmentOverrides: [
                "UITEST_POSITION_DEBUG": "1"
                // Note: NO "UITEST_DISABLE_AUDIO_ENGINE" key → uses real AVPlayer
            ]
        )
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
        guard startPlayback() else {
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
        guard startPlayback(), expandPlayer() else {
            XCTFail("Failed to start playback and expand player")
            return
        }

        // Wait for AVPlayer to start streaming and advance position
        let initialValue = getSliderValue()
        guard let advancedValue = waitForPositionAdvancement(beyond: initialValue, timeout: avplayerTimeout) else {
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
        guard startPlayback(), expandPlayer() else {
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
        guard startPlayback(), expandPlayer() else {
            XCTFail("Failed to start playback and expand player")
            return
        }

        let initialValue = getSliderValue()
        logSliderValue("initial (AVPlayer)", value: initialValue)

        // When: Seek to 50% position (calls AVPlayer.seek(to:))
        let slider = app.sliders.matching(identifier: "Progress Slider").firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: adaptiveShortTimeout))

        logBreadcrumb("testSeekingUpdatesPositionImmediately (AVPlayer): seek to 50%")
        let preSeekValue = getSliderValue()
        slider.adjust(toNormalizedSliderPosition: 0.5)

        // Then: Wait for position to change (AVPlayer seek may take time)
        // Use longer stabilization window for AVPlayer seek completion
        guard let seekedValue = waitForUIStabilization(
            afterSeekingFrom: preSeekValue,
            timeout: 5.0,  // Longer for AVPlayer seek
            minimumDelta: 3.0,
            stabilityWindow: 0.5  // Longer stability window
        ) else {
            XCTFail("Slider value should change after AVPlayer seek")
            return
        }
        logSliderValue("seeked (AVPlayer)", value: seekedValue)

        // Verify position continues advancing after seek
        guard let finalValue = waitForPositionAdvancement(beyond: seekedValue, timeout: avplayerTimeout) else {
            XCTFail("Position should continue advancing after AVPlayer seek")
            return
        }
        logSliderValue("final (AVPlayer)", value: finalValue)
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
        guard startPlayback() else {
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
}

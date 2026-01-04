// PlaybackPositionTickerTests.swift
import OSLog
import XCTest

/// UI tests for playback position using the Ticker engine (deterministic timing).
///
/// **Issue**: 03.3.2.2 - Create Playback Position Ticker Test Suite
/// **Parent Issue**: 03.3.2 - AVPlayer Playback Engine
/// **Mode**: Ticker (UITEST_DISABLE_AUDIO_ENGINE=1)
/// **Spec**: `zpod/spec/playback.md` - Core Playback Behavior
///
/// These tests validate position UI updates using the deterministic TimerTicker.
/// Fast execution (~10-15 seconds per test), no audio hardware required.
///
/// **CI Job**: UITests-PlaybackTicker
final class PlaybackPositionTickerTests: XCTestCase, PlaybackPositionTestSupport {

    nonisolated(unsafe) var app: XCUIApplication!
    static let logger = Logger(subsystem: "us.zig.zpod", category: "PlaybackPositionTickerTests")

    override func setUpWithError() throws {
        continueAfterFailure = false
        disableWaitingForIdleIfNeeded()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    private func launchApp() {
        app = .configuredForUITests(
            playbackMode: .ticker,
            environmentOverrides: [
                "UITEST_POSITION_DEBUG": "1"
            ]
        )
        app.launch()
    }

    // MARK: - Test 1: Position Advancement

    /// **Spec**: Timeline Advancement During Playback (lines 62-68)
    /// **Given**: An episode is playing
    /// **When**: Time passes during playback
    /// **Then**: Progress slider position advances
    @MainActor
    func testExpandedPlayerProgressAdvancesDuringPlayback() throws {
        // Given: Episode is playing
        launchApp()
        guard startPlayback() else {
            XCTFail("Failed to start playback")
            return
        }

        guard expandPlayer() else {
            XCTFail("Failed to expand player")
            return
        }

        // Capture initial slider value
        let initialValue = getSliderValue()
        XCTAssertNotNil(initialValue, "Progress slider should have an initial value")
        logSliderValue("initial", value: initialValue)
        let initialPosition = extractCurrentPosition(from: initialValue)

        // When: Wait for position to advance (ticker updates every 0.5s)
        let updatedValue = waitForPositionAdvancement(beyond: initialValue, timeout: 5.0)

        // Then: Progress slider should show advanced position
        XCTAssertNotNil(updatedValue, "Progress slider should have advanced")
        logSliderValue("updated", value: updatedValue)
        let updatedPosition = extractCurrentPosition(from: updatedValue)

        if let initial = initialPosition, let updated = updatedPosition {
            XCTAssertGreaterThan(updated, initial,
                "Position should advance from \(initial)s to \(updated)s")
            XCTAssertGreaterThanOrEqual(updated - initial, 1.0,
                "Position should advance at least 1.0s during playback")
        } else {
            XCTFail("Could not parse position values")
        }
    }

    // MARK: - Test 2: Pause Stops Position

    /// **Spec**: Pausing Playback (lines 69-76)
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

        // Wait for initial position advancement
        let initialValue = getSliderValue()
        _ = waitForPositionAdvancement(beyond: initialValue, timeout: 3.0)

        // When: Pause playback
        let pauseButton = app.buttons.matching(identifier: "Expanded Player Pause").firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Pause button should exist")
        pauseButton.tap()

        // Verify play button appears
        let playButton = app.buttons.matching(identifier: "Expanded Player Play").firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Play button should appear after pause")

        // Then: Verify position remains stable
        let pausedValue = getSliderValue()
        logSliderValue("paused", value: pausedValue)
        let positionStable = verifyPositionStable(at: pausedValue, forDuration: 2.0, tolerance: 0.1)
        XCTAssertTrue(positionStable, "Position should remain stable when paused")
    }

    // MARK: - Test 3: Resume Advances Position

    /// **Spec**: Resuming Playback (lines 77-84)
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
        logSliderValue("paused", value: pausedValue)
        let pausedPosition = extractCurrentPosition(from: pausedValue)

        // When: Resume playback
        playButton.tap()
        XCTAssertTrue(pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Pause button should reappear after resume")

        // Then: Position should advance
        let resumedValue = waitForPositionAdvancement(beyond: pausedValue, timeout: 5.0)
        XCTAssertNotNil(resumedValue, "Position should advance after resuming")
        logSliderValue("resumed", value: resumedValue)

        if let paused = pausedPosition,
           let resumed = extractCurrentPosition(from: resumedValue) {
            XCTAssertGreaterThan(resumed, paused,
                "Position should advance from \(paused)s to \(resumed)s after resume")
            XCTAssertGreaterThanOrEqual(resumed - paused, 1.0,
                "Position should advance at least 1.0s after resume")
        }
    }

    // MARK: - Test 4: Seeking Updates Position

    /// **Spec**: Seeking to Position (lines 85-87)
    /// **Given**: An episode is playing
    /// **When**: User seeks to a new position
    /// **Then**: Position updates immediately and continues advancing
    @MainActor
    func testSeekingUpdatesPositionImmediately() throws {
        logBreadcrumb("testSeekingUpdatesPositionImmediately: launch app")
        launchApp()
        guard startPlayback(), expandPlayer() else {
            XCTFail("Failed to start playback and expand player")
            return
        }

        let initialValue = getSliderValue()
        logSliderValue("initial", value: initialValue)

        // When: Seek to 50% position
        let slider = app.sliders.matching(identifier: "Progress Slider").firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: adaptiveShortTimeout))

        logBreadcrumb("testSeekingUpdatesPositionImmediately: seek to 50%")
        let preSeekValue = getSliderValue()
        slider.adjust(toNormalizedSliderPosition: 0.5)

        // Then: Wait for position to change significantly
        let seekedValue = waitForUIStabilization(
            afterSeekingFrom: preSeekValue,
            timeout: 3.0,
            minimumDelta: 3.0,
            stabilityWindow: 0.3
        )
        logSliderValue("seeked", value: seekedValue)
        XCTAssertNotNil(seekedValue, "Slider value should change after seek")

        // Verify position continues advancing after seek
        let finalValue = waitForPositionAdvancement(beyond: seekedValue, timeout: 5.0)
        logSliderValue("final", value: finalValue)
        XCTAssertNotNil(finalValue, "Position should continue advancing after seek")
    }

    // MARK: - Test 5: Mini-Player State

    /// **Spec**: Timeline Advancement During Playback - Mini-Player
    /// **Given**: An episode is playing
    /// **When**: Mini-player is visible
    /// **Then**: Mini-player reflects playback state (play/pause buttons)
    @MainActor
    func testMiniPlayerReflectsPlaybackState() throws {
        launchApp()
        guard startPlayback() else {
            XCTFail("Failed to start playback")
            return
        }

        // Then: Mini-player should show pause button
        let miniPlayer = miniPlayerElement(in: app)
        XCTAssertTrue(miniPlayer.exists, "Mini-player should be visible")

        let pauseButton = app.buttons.matching(identifier: "Mini Player Pause").firstMatch
        XCTAssertTrue(pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Mini-player should show pause button when playing")

        // When: Pause via mini-player
        pauseButton.tap()

        // Then: Play button should appear
        let playButton = app.buttons.matching(identifier: "Mini Player Play").firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: adaptiveShortTimeout),
            "Mini-player should show play button when paused")
    }
}

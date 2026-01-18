import OSLog
import XCTest

// ⚠️ DEPRECATED: This test file has been replaced by dual-mode playback tests
//
// **Replacement Files**:
// - `PlaybackPositionTickerTests.swift` - Deterministic ticker-based tests (5 tests)
// - `PlaybackPositionAVPlayerTests.swift` - Real AVPlayer integration tests (9 tests)
// - `PlaybackPositionTestSupport.swift` - Shared test helpers and protocol
//
// **Why Deprecated**:
// - New architecture validates both UI logic (ticker) and audio integration (AVPlayer)
// - Shared protocol eliminates code duplication
// - Better CI parallelization (separate jobs for ticker vs AVPlayer)
// - Clearer test intent (explicit mode selection)
//
// **Migration**: 
// - All scenarios from this file are covered in the new test files
// - See `docs/testing/PLAYBACK_TESTS.md` for complete dual-mode strategy
// - This file will be removed in Issue #TBD after verification period
//
// **Last Updated**: 2026-01-08 (Issue 03.3.2.5)

/// UI integration tests for playback position advancement and ticking engine.
///
/// **Issue**: 03.3.1 - Position Ticking Engine
/// **Spec**: `zpod/spec/playback.md` - Core Playback Behavior
///
/// Validates that position ticking updates propagate correctly to UI components:
/// - Expanded player progress slider advances during playback
/// - Position updates are reflected in accessibility values
/// - Seeking immediately updates position display
/// - Position persists correctly across app lifecycle
final class PlaybackPositionUITests: XCTestCase, SmartUITesting {

  nonisolated(unsafe) var app: XCUIApplication!
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "PlaybackPositionUITests")

  override func setUpWithError() throws {
    try super.setUpWithError()
    // Deprecated suite; keep discoverable for short-term traceability but skip by default.
    if ProcessInfo.processInfo.environment["UITEST_RUN_DEPRECATED"] != "1" {
      throw XCTSkip("Deprecated: use PlaybackPositionTickerTests or PlaybackPositionAVPlayerTests (see docs/testing/PLAYBACK_TESTS.md)")
    }
    continueAfterFailure = false
    disableWaitingForIdleIfNeeded()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - Helper Methods

  @MainActor
  private func launchApp() {
    app = launchConfiguredApp(environmentOverrides: ["UITEST_POSITION_DEBUG": "1"])
  }

  /// Navigate to Library tab and start playback
  @MainActor
  private func startPlayback() -> Bool {
    logBreadcrumb("startPlayback: select Library tab")
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
    guard libraryTab.waitForExistence(timeout: adaptiveTimeout) else {
      XCTFail("Library tab not found")
      return false
    }
    libraryTab.tap()

    // Wait for library content
    logBreadcrumb("startPlayback: waiting for library content")
    guard waitForContentToLoad(
      containerIdentifier: "Podcast Cards Container",
      timeout: adaptiveTimeout
    ) else {
      XCTFail("Library content failed to load")
      return false
    }

    // Navigate to podcast
    logBreadcrumb("startPlayback: open podcast")
    let podcastButton = app.buttons.matching(identifier: "Podcast-swift-talk").firstMatch
    guard podcastButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Podcast button not found")
      return false
    }
    podcastButton.tap()

    // Wait for episode list
    logBreadcrumb("startPlayback: waiting for episode list")
    guard waitForContentToLoad(
      containerIdentifier: "Episode List View",
      itemIdentifiers: ["Episode-st-001"],
      timeout: adaptiveTimeout
    ) else {
      XCTFail("Episode list failed to load")
      return false
    }

    // Start playback
    logBreadcrumb("startPlayback: tap quick play")
    tapQuickPlayButton(in: app, timeout: adaptiveShortTimeout)

    // Verify mini-player appeared
    logBreadcrumb("startPlayback: waiting for mini player")
    let miniPlayer = miniPlayerElement(in: app)
    guard miniPlayer.waitForExistence(timeout: adaptiveTimeout) else {
      XCTFail("Mini player did not appear after playback started")
      return false
    }

    return true
  }

  /// Expand mini-player to full player view
  @MainActor
  private func expandPlayer() -> Bool {
    logBreadcrumb("expandPlayer: tap mini player")
    let miniPlayer = miniPlayerElement(in: app)
    guard miniPlayer.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Mini player not visible")
      return false
    }

    miniPlayer.tap()

    let expandedPlayer = app.otherElements.matching(identifier: "Expanded Player").firstMatch
    logBreadcrumb("expandPlayer: waiting for expanded player")
    guard expandedPlayer.waitForExistence(timeout: adaptiveTimeout) else {
      XCTFail("Expanded player did not appear")
      return false
    }

    return true
  }

  @MainActor
  private func progressSlider() -> XCUIElement? {
    let expandedPlayer = app.otherElements.matching(identifier: "Expanded Player").firstMatch
    guard expandedPlayer.waitForExistence(timeout: adaptiveShortTimeout) else {
      return nil
    }
    return expandedPlayer.sliders.matching(identifier: "Progress Slider").firstMatch
  }

  /// Get the progress slider's current value
  @MainActor
  private func getSliderValue() -> String? {
    guard let slider = progressSlider(),
          slider.waitForExistence(timeout: adaptiveShortTimeout) else { return nil }
    return slider.value as? String
  }

  @MainActor
  private func logSliderValue(_ label: String, value: String?) {
    guard ProcessInfo.processInfo.environment["UITEST_POSITION_DEBUG"] == "1" else { return }
    let resolvedValue = value ?? "nil"
    Self.logger.info("\(label, privacy: .public): \(resolvedValue, privacy: .public)")
  }

  @MainActor
  private func logBreadcrumb(_ message: String) {
    guard ProcessInfo.processInfo.environment["UITEST_POSITION_DEBUG"] == "1" else { return }
    Self.logger.info("\(message, privacy: .public)")
  }

  /// Extract numeric position from slider value string (format: "X of Y")
  @MainActor
  private func extractCurrentPosition(from value: String?) -> TimeInterval? {
    guard let value = value else { return nil }

    // Value format: "0:30 of 60:00" or similar
    let components = value.components(separatedBy: " of ")
    guard let timeString = components.first else { return nil }

    return parseTimeString(timeString)
  }

  /// Parse time string "MM:SS" or "H:MM:SS" to seconds
  @MainActor
  private func parseTimeString(_ timeString: String) -> TimeInterval? {
    let components = timeString.components(separatedBy: ":")

    if components.count == 2 {
      // MM:SS format
      guard let minutes = Int(components[0]),
            let seconds = Int(components[1]) else { return nil }
      return TimeInterval(minutes * 60 + seconds)
    } else if components.count == 3 {
      // H:MM:SS format
      guard let hours = Int(components[0]),
            let minutes = Int(components[1]),
            let seconds = Int(components[2]) else { return nil }
      return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    return nil
  }

  /// Wait for the slider position to advance beyond the initial value.
  /// Uses predicate-based waiting instead of Thread.sleep for reliability.
  @MainActor
  private func waitForPositionAdvancement(
    beyond initialValue: String?,
    timeout: TimeInterval = 5.0
  ) -> String? {
    guard let slider = progressSlider(),
          slider.waitForExistence(timeout: adaptiveShortTimeout) else { return nil }

    let initialPosition = extractCurrentPosition(from: initialValue) ?? 0

    var observedValue: String?
    let advanced = waitForState(
      timeout: timeout,
      pollInterval: 0.1,
      description: "position advancement"
    ) {
      guard let currentValue = slider.value as? String,
            let currentPosition = self.extractCurrentPosition(from: currentValue) else {
        return false
      }
      if currentPosition > initialPosition + 1.0 {
        observedValue = currentValue
        return true
      }
      return false
    }

    return advanced ? observedValue : nil
  }

  /// Wait for the slider value to change after a seek and then stabilize (no longer ticking).
  /// Leverages UITestStableWaitHelpers primitives to avoid reading stale pre-seek values.
  @MainActor
  private func waitForUIStabilization(
    afterSeekingFrom initialValue: String?,
    timeout: TimeInterval = 3.0,  // Increased from 2.0s to 3.0s for more tolerance
    minimumDelta: TimeInterval = 3.0,  // Reduced from 5.0s to 3.0s for less strict requirement
    stabilityWindow: TimeInterval = 0.3  // Increased from 0.2s to 0.3s for more stability
  ) -> String? {
    guard let slider = progressSlider(),
          slider.waitForExistence(timeout: adaptiveShortTimeout) else { return nil }

    let deadline = Date().addingTimeInterval(timeout)
    let initialPosition = extractCurrentPosition(from: initialValue)

    // Wait for the slider to reflect a new position (not just exist)
    let changeObserved = waitForState(
      timeout: timeout,
      pollInterval: 0.1,
      description: "slider value change"
    ) {
      guard let value = slider.value as? String else {
        return false
      }

      if let initialPosition {
        guard let currentPosition = self.extractCurrentPosition(from: value) else {
          return false
        }
        return abs(currentPosition - initialPosition) >= minimumDelta
      }

      // Fallback when we cannot parse initial position: require any value change
      return value != initialValue
    }

    guard changeObserved else {
      return nil
    }

    let remainingTimeout = max(0.1, deadline.timeIntervalSinceNow)
    guard slider.waitForValueStable(
      timeout: remainingTimeout,
      stabilityWindow: stabilityWindow,
      checkInterval: 0.05
    ) else {
      return nil
    }

    return slider.value as? String
  }

  /// Verify position remains stable (hasn't advanced) over a period.
  /// Returns true if position stayed close to expected value, false if it drifted.
  @MainActor
  private func verifyPositionStable(
    at expectedValue: String?,
    forDuration: TimeInterval = 2.0,
    tolerance: TimeInterval = 0.1
  ) -> Bool {
    guard let slider = progressSlider(),
          slider.waitForExistence(timeout: adaptiveShortTimeout) else { return false }

    guard let expectedPosition = extractCurrentPosition(from: expectedValue) else {
      return false
    }
    let deadline = Date().addingTimeInterval(forDuration)
    var observedWithinTolerance = false

    while Date() < deadline {
      // Use RunLoop to allow UI events to be processed
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))

      guard let currentValue = slider.value as? String,
            let currentPosition = extractCurrentPosition(from: currentValue) else {
        continue
      }

      let deviation = abs(currentPosition - expectedPosition)
      if deviation > tolerance {
        return false  // Position drifted beyond tolerance
      }

      observedWithinTolerance = true
    }

    return observedWithinTolerance  // Position remained close to expected value
  }

  // MARK: - Position Advancement Tests

  /// **Spec**: Timeline Advancement During Playback
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
    let initialPosition = extractCurrentPosition(from: initialValue)

    // When: Wait for position to advance using predicate-based waiting
    // This waits for at least 1 second of position advancement (more reliable than Thread.sleep)
    let updatedValue = waitForPositionAdvancement(beyond: initialValue, timeout: 5.0)

    // Then: Progress slider should show advanced position
    XCTAssertNotNil(updatedValue, "Progress slider should have advanced")
    let updatedPosition = extractCurrentPosition(from: updatedValue)

    // Verify position advanced
    if let initial = initialPosition, let updated = updatedPosition {
      XCTAssertGreaterThan(
        updated,
        initial,
        "Position should have advanced from \(initial)s to \(updated)s"
      )

      // Position should have advanced at least 1 second (what we waited for)
      let advancement = updated - initial
      XCTAssertGreaterThanOrEqual(
        advancement,
        1.0,
        "Position should advance at least 1.0s during playback (got \(advancement)s)"
      )
    } else {
      XCTFail("Could not parse position values - initial: \(String(describing: initialPosition)), updated: \(String(describing: updatedPosition))")
    }
  }

  /// **Spec**: Pausing Playback
  /// **Given**: An episode is playing with advancing position
  /// **When**: User pauses playback
  /// **Then**: Position stops advancing
  @MainActor
  func testPositionStopsAdvancingWhenPaused() throws {
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

    // Wait for initial position advancement using predicate-based waiting
    let initialValue = getSliderValue()
    _ = waitForPositionAdvancement(beyond: initialValue, timeout: 3.0)

    // When: Pause playback
    let pauseButton = app.buttons.matching(identifier: "Expanded Player Pause").firstMatch
    XCTAssertTrue(
      pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
      "Pause button should be visible when playing"
    )
    pauseButton.tap()

    // Verify play button appears (indicating paused state)
    let playButton = app.buttons.matching(identifier: "Expanded Player Play").firstMatch
    XCTAssertTrue(
      playButton.waitForExistence(timeout: adaptiveShortTimeout),
      "Play button should appear after pausing"
    )

    // Capture position immediately after pause
    let pausedValue = getSliderValue()

    // Then: Verify position hasn't advanced using RunLoop-based waiting
    let positionStable = verifyPositionStable(at: pausedValue, forDuration: 2.0, tolerance: 0.1)
    XCTAssertTrue(positionStable, "Position should remain stable when paused (within 0.1s)")
  }

  /// **Spec**: Resuming Playback
  /// **Given**: An episode is paused
  /// **When**: User resumes playback
  /// **Then**: Position resumes advancing from paused position
  @MainActor
  func testPositionResumesAdvancingAfterPause() throws {
    // Given: Episode is paused
    launchApp()
    guard startPlayback() else {
      XCTFail("Failed to start playback")
      return
    }

    guard expandPlayer() else {
      XCTFail("Failed to expand player")
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

    // When: Resume playback
    playButton.tap()

    // Verify pause button reappears (indicating playing state)
    XCTAssertTrue(
      pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
      "Pause button should reappear after resuming"
    )

    // Then: Position should advance from paused position using predicate-based waiting
    let resumedValue = waitForPositionAdvancement(beyond: pausedValue, timeout: 5.0)
    XCTAssertNotNil(resumedValue, "Position should advance after resuming")

    let resumedPosition = extractCurrentPosition(from: resumedValue)

    if let paused = pausedPosition, let resumed = resumedPosition {
      XCTAssertGreaterThan(
        resumed,
        paused,
        "Position should advance from \(paused)s to \(resumed)s after resuming"
      )

      let advancement = resumed - paused
      XCTAssertGreaterThanOrEqual(
        advancement,
        1.0,
        "Position should advance at least 1.0s after resume (got \(advancement)s)"
      )
    } else {
      XCTFail("Could not parse resumed position values")
    }
  }

  /// **Spec**: Seeking to Position
  /// **Given**: An episode is playing
  /// **When**: User seeks to a new position
  /// **Then**: Position updates immediately and continues advancing
  @MainActor
  func testSeekingUpdatesPositionImmediately() throws {
    // Given: Episode is playing
    logBreadcrumb("testSeekingUpdatesPositionImmediately: launch app")
    launchApp()
    guard startPlayback() else {
      XCTFail("Failed to start playback")
      return
    }

    guard expandPlayer() else {
      XCTFail("Failed to expand player")
      return
    }

    // Get initial position
    logBreadcrumb("testSeekingUpdatesPositionImmediately: capture initial slider value")
    guard let initialValue = getSliderValue() else {
      XCTFail("Progress slider has no initial value")
      return
    }
    logSliderValue("initial", value: initialValue)

    guard let baselineValue = waitForPositionAdvancement(beyond: initialValue, timeout: 5.0) else {
      XCTFail("Progress slider did not advance before seeking")
      return
    }
    logSliderValue("baseline", value: baselineValue)

    // When: Seek to a new position via the slider
    guard let initialPosition = extractCurrentPosition(from: baselineValue),
          let durationString = baselineValue.components(separatedBy: " of ").last,
          let totalDuration = extractCurrentPosition(from: durationString),
          totalDuration > 0 else {
      XCTFail("Could not parse baseline position and duration from slider")
      return
    }

    let currentRatio = max(0.0, min(1.0, initialPosition / totalDuration))
    let lowTarget = 0.2
    let highTarget = 0.8
    let targetNormalized =
      abs(currentRatio - lowTarget) > abs(currentRatio - highTarget)
      ? lowTarget
      : highTarget
    let targetPosition = totalDuration * targetNormalized
    let expectedDelta = abs(targetPosition - initialPosition)
    let minimumDelta = max(0.4, min(2.0, expectedDelta * 0.6))

    guard let slider = progressSlider() else {
      XCTFail("Progress slider not found in expanded player")
      return
    }
    XCTAssertTrue(slider.waitForExistence(timeout: adaptiveShortTimeout))

    let targetPercent = Int((targetNormalized * 100).rounded())
    logBreadcrumb("testSeekingUpdatesPositionImmediately: seek to \(targetPercent)%")
    let preSeekValue = getSliderValue() ?? baselineValue
    logSliderValue("pre-seek", value: preSeekValue)
    slider.adjust(toNormalizedSliderPosition: targetNormalized)

    // Then: Wait for slider value to change and stabilize after seek (position must change significantly)
    let seekedValue = waitForUIStabilization(
      afterSeekingFrom: preSeekValue,
      timeout: 3.0,
      minimumDelta: minimumDelta,
      stabilityWindow: 0.3
    )
    logSliderValue("seeked", value: seekedValue)
    XCTAssertNotNil(seekedValue, "Slider value should change after seek")

    guard let seekedPosition = extractCurrentPosition(from: seekedValue) else {
      XCTFail("Could not parse seek position values")
      return
    }
    let positionDelta = abs(seekedPosition - targetPosition)
    XCTAssertLessThan(
      positionDelta,
      totalDuration * 0.15,
      "Seeked position \(seekedPosition)s should be close to \(targetPercent)% mark (\(targetPosition)s)"
    )

    // Verify playback continues advancing after seek using predicate-based waiting
    logBreadcrumb("testSeekingUpdatesPositionImmediately: wait for advancement")
    let finalValue = waitForPositionAdvancement(beyond: seekedValue, timeout: 5.0)
    logSliderValue("final", value: finalValue)
    XCTAssertNotNil(finalValue, "Position should continue advancing after seek")

    let finalPosition = extractCurrentPosition(from: finalValue)

    if let final = finalPosition {
      XCTAssertGreaterThan(
        final,
        seekedPosition,
        "Position should continue advancing after seek from \(seekedPosition)s to \(final)s"
      )
    } else {
      XCTFail("Could not parse final position values")
    }
  }

  // MARK: - Mini-Player Position Tests

  /// **Spec**: Timeline Advancement During Playback (Mini-Player)
  /// **Given**: An episode is playing
  /// **When**: Mini-player is visible
  /// **Then**: Mini-player reflects playback state
  ///
  /// Note: Mini-player may not show visual timeline, but should reflect playing state
  @MainActor
  func testMiniPlayerReflectsPlaybackState() throws {
    // Given: Episode is playing
    launchApp()
    guard startPlayback() else {
      XCTFail("Failed to start playback")
      return
    }

    // Then: Mini-player should show pause button (indicating playing state)
    let miniPlayer = miniPlayerElement(in: app)
    XCTAssertTrue(miniPlayer.exists, "Mini player should be visible")

    let pauseButton = app.buttons.matching(identifier: "Mini Player Pause").firstMatch
    XCTAssertTrue(
      pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player should show pause button when playing"
    )

    // When: Pause via mini-player
    pauseButton.tap()

    // Then: Play button should appear
    let playButton = app.buttons.matching(identifier: "Mini Player Play").firstMatch
    XCTAssertTrue(
      playButton.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player should show play button when paused"
    )
  }
}

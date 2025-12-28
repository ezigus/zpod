import XCTest

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

  override func setUpWithError() throws {
    continueAfterFailure = false
    disableWaitingForIdleIfNeeded()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - Helper Methods

  @MainActor
  private func launchApp() {
    app = launchConfiguredApp()
  }

  /// Navigate to Library tab and start playback
  @MainActor
  private func startPlayback() -> Bool {
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
    guard libraryTab.waitForExistence(timeout: adaptiveTimeout) else {
      XCTFail("Library tab not found")
      return false
    }
    libraryTab.tap()

    // Wait for library content
    guard waitForContentToLoad(
      containerIdentifier: "Podcast Cards Container",
      timeout: adaptiveTimeout
    ) else {
      XCTFail("Library content failed to load")
      return false
    }

    // Navigate to podcast
    let podcastButton = app.buttons.matching(identifier: "Podcast-swift-talk").firstMatch
    guard podcastButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Podcast button not found")
      return false
    }
    podcastButton.tap()

    // Wait for episode list
    guard waitForContentToLoad(
      containerIdentifier: "Episode List View",
      itemIdentifiers: ["Episode-st-001"],
      timeout: adaptiveTimeout
    ) else {
      XCTFail("Episode list failed to load")
      return false
    }

    // Start playback
    tapQuickPlayButton(in: app, timeout: adaptiveShortTimeout)

    // Verify mini-player appeared
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
    let miniPlayer = miniPlayerElement(in: app)
    guard miniPlayer.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Mini player not visible")
      return false
    }

    miniPlayer.tap()

    let expandedPlayer = app.otherElements.matching(identifier: "Expanded Player").firstMatch
    guard expandedPlayer.waitForExistence(timeout: adaptiveTimeout) else {
      XCTFail("Expanded player did not appear")
      return false
    }

    return true
  }

  /// Get the progress slider's current value
  @MainActor
  private func getSliderValue() -> String? {
    let slider = app.sliders.matching(identifier: "Progress Slider").firstMatch
    guard slider.waitForExistence(timeout: adaptiveShortTimeout) else {
      return nil
    }
    return slider.value as? String
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

    // When: Wait for position to advance (ticker runs every 0.5s)
    // Wait 2 seconds to ensure at least 4 ticks have occurred
    Thread.sleep(forTimeInterval: 2.0)

    // Then: Progress slider should show advanced position
    let updatedValue = getSliderValue()
    XCTAssertNotNil(updatedValue, "Progress slider should have an updated value")
    let updatedPosition = extractCurrentPosition(from: updatedValue)

    // Verify position advanced
    if let initial = initialPosition, let updated = updatedPosition {
      XCTAssertGreaterThan(
        updated,
        initial,
        "Position should have advanced from \(initial)s to \(updated)s"
      )

      // Position should have advanced at least 1.5 seconds (allowing for timing variance)
      let advancement = updated - initial
      XCTAssertGreaterThanOrEqual(
        advancement,
        1.5,
        "Position should advance at least 1.5s in 2 seconds of playback (got \(advancement)s)"
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

    // Wait for initial position advancement
    Thread.sleep(forTimeInterval: 1.0)

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
    let pausedPosition = extractCurrentPosition(from: pausedValue)

    // Then: Wait and verify position hasn't advanced
    Thread.sleep(forTimeInterval: 2.0)

    let stillPausedValue = getSliderValue()
    let stillPausedPosition = extractCurrentPosition(from: stillPausedValue)

    if let paused = pausedPosition, let stillPaused = stillPausedPosition {
      // Allow 0.1s tolerance for timing variance
      XCTAssertEqual(
        stillPaused,
        paused,
        accuracy: 0.1,
        "Position should remain at \(paused)s when paused, but got \(stillPaused)s"
      )
    } else {
      XCTFail("Could not parse paused position values")
    }
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

    // Then: Position should advance from paused position
    Thread.sleep(forTimeInterval: 2.0)

    let resumedValue = getSliderValue()
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
        1.5,
        "Position should advance at least 1.5s after resume (got \(advancement)s)"
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
    let initialValue = getSliderValue()
    let initialPosition = extractCurrentPosition(from: initialValue)

    // When: Seek to a new position via the slider
    let slider = app.sliders.matching(identifier: "Progress Slider").firstMatch
    XCTAssertTrue(slider.waitForExistence(timeout: adaptiveShortTimeout))

    // Seek to 50% position
    slider.adjust(toNormalizedSliderPosition: 0.5)

    // Then: Position should update immediately
    Thread.sleep(forTimeInterval: 0.5)  // Brief pause for seek to complete

    let seekedValue = getSliderValue()
    let seekedPosition = extractCurrentPosition(from: seekedValue)

    // Verify position changed significantly (not just ticking)
    if let initial = initialPosition, let seeked = seekedPosition {
      let difference = abs(seeked - initial)
      XCTAssertGreaterThan(
        difference,
        5.0,
        "Seek should move position significantly (at least 5s), got \(difference)s change"
      )
    } else {
      XCTFail("Could not parse seek position values")
    }

    // Verify playback continues advancing after seek
    Thread.sleep(forTimeInterval: 2.0)

    let finalValue = getSliderValue()
    let finalPosition = extractCurrentPosition(from: finalValue)

    if let seeked = seekedPosition, let final = finalPosition {
      XCTAssertGreaterThan(
        final,
        seeked,
        "Position should continue advancing after seek from \(seeked)s to \(final)s"
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

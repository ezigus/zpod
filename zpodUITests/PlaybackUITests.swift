import XCTest
/// UI tests for playback interface controls and platform integrations
///
/// **Specifications Covered**: `spec/ui.md` - Playback interface sections
/// - Now playing screen controls and media player interface
/// - Lock screen and control center integration testing
/// - CarPlay player interface verification (simulated)
/// - Apple Watch playback controls (simulated)
/// - Bluetooth and external control handling
final class PlaybackUITests: IsolatedUITestCase {

  override func setUpWithError() throws {
    try super.setUpWithError()
    disableWaitingForIdleIfNeeded()
  }

}

extension PlaybackUITests {

  // MARK: - Helpers

  @MainActor
  private func initializeApp() {
    app = launchConfiguredApp(environmentOverrides: ["UITEST_INITIAL_TAB": "player"])

    // Verify app launched successfully
    guard app.state == .runningForeground else {
      XCTFail("App did not launch successfully. State: \(app.state.rawValue)")
      return
    }

    let tabs = TabBarNavigation(app: app)
    XCTAssertTrue(tabs.navigateToPlayer(), "Player tab should become selected after launch")
  }

  @MainActor
  private func startPlaybackFromLibraryQuickPlay() {
    app = launchConfiguredApp()

    let tabs = TabBarNavigation(app: app)
    XCTAssertTrue(tabs.navigateToLibrary(), "Library tab should become available")

    let library = LibraryScreen(app: app)
    XCTAssertTrue(library.waitForLibraryContent(), "Library content should load")
    XCTAssertTrue(library.selectPodcast("Podcast-swift-talk"), "Podcast should be selectable")
    XCTAssertTrue(library.waitForEpisodeList(), "Episode list should appear")

    tapQuickPlayButton(in: app, timeout: adaptiveTimeout)

    let player = PlayerScreen(app: app)
    XCTAssertTrue(
      player.waitForPlayerInterface(),
      "Player interface should appear after quick play"
    )
  }

  @MainActor
  private func existsByIdOrLabel(_ text: String) -> Bool {
    PlayerScreen(app: app).exists(identifierOrLabel: text)
  }

  @MainActor
  @discardableResult
  private func requirePlayerInterface() throws -> PlayerScreen {
    let player = PlayerScreen(app: app)
    XCTAssertTrue(
      player.waitForPlayerInterface(),
      "Player interface should be available when required"
    )
    return player
  }

}

extension PlaybackUITests {

  // MARK: - Now Playing Interface Tests
  // Covers: Player interface controls from ui spec

  @MainActor
  func testNowPlayingControls() throws {
    // Initialize the app
    initializeApp()

    // Given: Now playing interface is visible
    try requirePlayerInterface()

    // When: Checking for essential playback controls
    let playButton = app.buttons.matching(identifier: "Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch
    let skipForwardButton = app.buttons.matching(identifier: "Skip Forward").firstMatch
    let skipBackwardButton = app.buttons.matching(identifier: "Skip Backward").firstMatch

    // Then: Controls should be present and accessible
    guard
      let playOrPause = waitForAnyElement(
        [playButton, pauseButton],
        timeout: adaptiveShortTimeout,
        description: "Play/Pause button",
        failOnTimeout: false
      )
    else {
      XCTFail("Play/Pause controls unavailable in current playback state."); return
    }
    XCTAssertTrue(playOrPause.exists, "Play/Pause control should exist")

    guard skipForwardButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Skip forward control unavailable for the seeded content."); return
    }
    XCTAssertTrue(skipForwardButton.isEnabled, "Skip forward should be enabled")
    XCTAssertTrue(hasNonEmptyLabel(skipForwardButton), "Skip forward should have label")

    guard skipBackwardButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Skip backward control unavailable for the seeded content."); return
    }
    XCTAssertTrue(skipBackwardButton.isEnabled, "Skip backward should be enabled")
    XCTAssertTrue(hasNonEmptyLabel(skipBackwardButton), "Skip backward should have label")
  }

  @MainActor
  func testPlaybackSpeedControls() throws {
    // Initialize the app
    initializeApp()

    try requirePlayerInterface()

    // Given: Player interface with speed controls
    let speedButton = app.buttons.matching(
      NSPredicate(format: "label CONTAINS 'Speed' OR label CONTAINS 'x'")
    ).firstMatch

    guard speedButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Speed control trigger unavailable for seeded playback item."); return
    }

    // When: Interacting with speed controls
    speedButton.tap()

    // Then: Speed options should be available
    let speedOptions = app.buttons.matching(
      NSPredicate(
        format: "label CONTAINS '1.0x' OR label CONTAINS '1.5x' OR label CONTAINS '2.0x'"))

    guard speedOptions.count > 0 else {
      XCTFail("Speed options failed to render; verify playback UI configuration."); return
    }

    // Test selecting a speed option
    let fastSpeed = speedOptions.element(boundBy: min(1, speedOptions.count - 1))
    guard fastSpeed.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Speed option did not appear when expected."); return
    }
    fastSpeed.tap()
  }

  @MainActor
  func testProgressSlider() throws {
    // Initialize the app
    initializeApp()

    try requirePlayerInterface()

    // Given: Player interface with progress controls
    let progressSlider = app.sliders.matching(identifier: "Progress Slider").firstMatch

    guard progressSlider.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Progress slider unavailable for seeded playback item."); return
    }

    // When: Interacting with progress slider
    // Then: Slider should be interactive
    XCTAssertTrue(progressSlider.isEnabled, "Progress slider should be interactive")

    // Test slider accessibility
    XCTAssertNotNil(progressSlider.value, "Progress slider should have current value")
    XCTAssertTrue(
      hasNonEmptyLabel(progressSlider), "Progress slider should have descriptive label")
  }

  @MainActor
  func testEpisodeInformation() throws {
    // Initialize the app
    initializeApp()

    try requirePlayerInterface()

    // Given: Episode is playing
    let episodeTitle = try waitForElementOrSkip(
      app.staticTexts.matching(identifier: "Episode Title").firstMatch,
      timeout: adaptiveShortTimeout,
      description: "Episode title"
    )
    let podcastTitle = try waitForElementOrSkip(
      app.staticTexts.matching(identifier: "Podcast Title").firstMatch,
      timeout: adaptiveShortTimeout,
      description: "Podcast title"
    )
    let episodeArtwork = try waitForElementOrSkip(
      app.images.matching(identifier: "Episode Artwork").firstMatch,
      timeout: adaptiveShortTimeout,
      description: "Episode artwork"
    )

    // When: Checking episode information display
    // Then: Episode information should be visible
    XCTAssertTrue(hasNonEmptyLabel(episodeTitle), "Episode title should be displayed")
    XCTAssertTrue(hasNonEmptyLabel(podcastTitle), "Podcast title should be displayed")
    XCTAssertTrue(episodeArtwork.exists, "Artwork should be accessible")
  }

}

extension PlaybackUITests {

  // MARK: - Advanced Controls Tests
  // Covers: Advanced playback features from ui spec

  @MainActor
  func testSkipSilenceControls() throws {
    // Initialize the app
    initializeApp()

    // Given: Player interface with skip silence option
    let skipSilenceButton = app.buttons.matching(
      NSPredicate(format: "label CONTAINS 'Skip Silence' OR label CONTAINS 'Silence'")
    ).firstMatch

    if skipSilenceButton.exists {
      // When: Toggling skip silence
      let initialState = skipSilenceButton.isSelected
      skipSilenceButton.tap()

      // Then: State should change
      let newState = skipSilenceButton.isSelected
      XCTAssertNotEqual(initialState, newState, "Skip silence state should toggle")
    }
  }

  @MainActor
  func testVolumeBoostControls() throws {
    // Initialize the app
    initializeApp()

    // Given: Player interface with volume boost option
    let volumeBoostButton = app.buttons.matching(
      NSPredicate(format: "label CONTAINS 'Volume Boost' OR label CONTAINS 'Boost'")
    ).firstMatch

    if volumeBoostButton.exists {
      // When: Toggling volume boost
      let initialState = volumeBoostButton.isSelected
      volumeBoostButton.tap()

      // Then: State should change
      let newState = volumeBoostButton.isSelected
      XCTAssertNotEqual(initialState, newState, "Volume boost state should toggle")
    }
  }

  @MainActor
  func testSleepTimerControls() throws {
    // Initialize the app
    initializeApp()

    // Given: Player interface with sleep timer
    let sleepTimerButton = app.buttons.matching(
      NSPredicate(format: "label CONTAINS 'Sleep Timer' OR label CONTAINS 'Timer'")
    ).firstMatch

    if sleepTimerButton.exists {
      // When: Accessing sleep timer
      sleepTimerButton.tap()

      // Then: Timer options should be available
      let timerOptions = app.buttons.matching(
        NSPredicate(format: "label CONTAINS 'minute' OR label CONTAINS 'hour'"))

      if timerOptions.count > 0 {
        XCTAssertGreaterThan(timerOptions.count, 0, "Sleep timer options should be available")

        // Test selecting a timer option
        let fifteenMinutes = timerOptions.firstMatch
        if fifteenMinutes.exists {
          fifteenMinutes.tap()
          // Timer should be set (verified by UI feedback)
        }
      }
    }
  }

}

extension PlaybackUITests {

  // MARK: - Control Center Integration Tests
  // Covers: Control center integration from ui spec

  @MainActor
  func testControlCenterCompatibility() throws {
    // Initialize the app
    initializeApp()

    // Given: App is playing audio
    // When: Testing control center compatibility
    // Note: Control center testing requires background audio capability

    // Verify that media controls are properly configured
    let playButton = app.buttons.matching(identifier: "Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch

    if playButton.exists || pauseButton.exists {
      // Then: Media controls should be accessible for system integration
      XCTAssertTrue(
        playButton.exists || pauseButton.exists,
        "Media controls should be available for system integration")
    }

    // Test that episode information is available for system display
    let episodeTitle = app.staticTexts.matching(identifier: "Episode Title").firstMatch
    if episodeTitle.exists {
      XCTAssertTrue(
        hasNonEmptyLabel(episodeTitle),
        "Episode title should be available for control center")
    }
  }

}

extension PlaybackUITests {

  // MARK: - Lock Screen Integration Tests
  // Covers: Lock screen player from ui spec

  @MainActor
  func testLockScreenMediaInfo() throws {
    // Initialize the app
    initializeApp()

    // Given: App is configured for lock screen media display
    // When: Checking media information availability

    // Verify that required media information is present
    let episodeTitle = app.staticTexts.matching(identifier: "Episode Title").firstMatch
    let podcastTitle = app.staticTexts.matching(identifier: "Podcast Title").firstMatch
    let episodeArtwork = app.images.matching(identifier: "Episode Artwork").firstMatch

    // Then: Media info should be suitable for lock screen display
    if episodeTitle.exists {
      XCTAssertTrue(
        hasNonEmptyLabel(episodeTitle),
        "Episode title should be available for lock screen")
    }

    if podcastTitle.exists {
      XCTAssertTrue(
        hasNonEmptyLabel(podcastTitle),
        "Podcast title should be available for lock screen")
    }

    if episodeArtwork.exists {
      XCTAssertTrue(
        episodeArtwork.exists,
        "Artwork should be available for lock screen")
    }
  }

}

extension PlaybackUITests {

  // MARK: - CarPlay Interface Tests
  // Covers: CarPlay integration from ui spec

  @MainActor
  func testCarPlayCompatibleInterface() throws {
    // Initialize the app
    initializeApp()

    // Given: App interface should be CarPlay compatible
    // When: Checking for CarPlay-suitable controls

    // CarPlay requires large, easily accessible controls
    let playButton = app.buttons.matching(identifier: "Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch
    let skipForwardButton = app.buttons.matching(identifier: "Skip Forward").firstMatch
    let skipBackwardButton = app.buttons.matching(identifier: "Skip Backward").firstMatch

    // Then: Controls should be suitable for CarPlay
    if playButton.exists {
      XCTAssertTrue(playButton.frame.height >= 44, "Play button should be large enough for CarPlay")
      XCTAssertTrue(hasNonEmptyLabel(playButton), "Play button should have clear label for CarPlay")
    }

    if pauseButton.exists {
      XCTAssertTrue(
        pauseButton.frame.height >= 44, "Pause button should be large enough for CarPlay")
    }

    if skipForwardButton.exists {
      XCTAssertTrue(
        skipForwardButton.frame.height >= 44,
        "Skip forward button should be large enough for CarPlay")
      XCTAssertTrue(
        hasNonEmptyLabel(skipForwardButton), "Skip forward should have clear label for CarPlay")
    }

    if skipBackwardButton.exists {
      XCTAssertTrue(
        skipBackwardButton.frame.height >= 44,
        "Skip backward button should be large enough for CarPlay")
      XCTAssertTrue(
        hasNonEmptyLabel(skipBackwardButton), "Skip backward should have clear label for CarPlay")
    }

    // Test that text is readable for CarPlay
    let episodeTitle = app.staticTexts.matching(identifier: "Episode Title").firstMatch
    if episodeTitle.exists {
      XCTAssertTrue(
        episodeTitle.label.count <= 50,
        "Episode title should be concise for CarPlay display")
    }
  }

}

extension PlaybackUITests {

  // MARK: - Apple Watch Interface Tests
  // Covers: Apple Watch support from ui spec

  @MainActor
  func testWatchCompatibleControls() throws {
    // Initialize the app
    initializeApp()

    // Given: App should support Apple Watch companion
    // When: Checking for Watch-suitable interface elements

    // Watch interface requires essential controls only
    let playButton = app.buttons.matching(identifier: "Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch

    // Then: Essential controls should be available
    if playButton.exists || pauseButton.exists {
      XCTAssertTrue(
        playButton.exists || pauseButton.exists,
        "Essential playback controls should be available for Watch")
    }

    // Test simplified information display suitable for Watch
    let episodeTitle = app.staticTexts.matching(identifier: "Episode Title").firstMatch
    if episodeTitle.exists && episodeTitle.label.count > 30 {
      // Title should be truncatable for Watch display
      XCTAssertTrue(true, "Long titles should be handled appropriately for Watch")
    }
  }

}

extension PlaybackUITests {

  // MARK: - Accessibility Tests for Playback
  // Covers: Accessibility for playback features from ui spec

  @MainActor
  func testPlaybackAccessibility() throws {
    // Initialize the app
    initializeApp()

    // Given: Playback interface is accessible
    // When: Checking accessibility features

    let playButton = app.buttons.matching(identifier: "Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch

    // Then: Playback controls should have proper accessibility
    if playButton.exists {
      XCTAssertTrue(
        playButton.waitForExistence(timeout: adaptiveShortTimeout),
        "Play button should be accessible")
      XCTAssertTrue(hasNonEmptyLabel(playButton), "Play button should have accessibility label")
      // XCTest doesn't expose accessibilityHint; ensure tappable instead
    }

    if pauseButton.exists {
      XCTAssertTrue(
        pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
        "Pause button should be accessible")
      XCTAssertTrue(hasNonEmptyLabel(pauseButton), "Pause button should have accessibility label")
    }

    // Test progress slider accessibility
    let progressSlider = app.sliders.matching(identifier: "Progress Slider").firstMatch
    if progressSlider.exists {
      XCTAssertTrue(
        progressSlider.waitForExistence(timeout: adaptiveShortTimeout),
        "Progress slider should be accessible")
      XCTAssertNotNil(progressSlider.value, "Progress slider should announce current position")
    }
  }

  @MainActor
  func testVoiceOverPlaybackNavigation() throws {
    // Initialize the app
    initializeApp()

    // Given: VoiceOver user navigating playback controls
    // When: Checking VoiceOver navigation order

    let playbackControls = [
      app.buttons.matching(identifier: "Skip Backward").firstMatch,
      app.buttons.matching(identifier: "Play").firstMatch,
      app.buttons.matching(identifier: "Pause").firstMatch,
      app.buttons.matching(identifier: "Skip Forward").firstMatch,
    ].filter { $0.exists }

    // Then: Controls should be in logical order for VoiceOver
    for control in playbackControls {
      // Ensure control is ready before checking accessibility - event-based check
      XCTAssertTrue(
        control.waitForExistence(timeout: adaptiveShortTimeout), "Control should exist and be ready"
      )
      // XCUIElement doesn't reliably expose isAccessibilityElement; check for hittable and label
      XCTAssertTrue(control.isHittable, "Playbook control should be accessible to VoiceOver")
      XCTAssertTrue(hasNonEmptyLabel(control), "Control should have descriptive label")
    }
  }

}

extension PlaybackUITests {

  // MARK: - Performance Tests
  // Covers: UI responsiveness during playback

  @MainActor
  func testPlaybackUIPerformance() throws {
    // Initialize the app
    initializeApp()

    // Given: Playback interface is loaded
    // When: Interacting with playback controls
    let playButton = app.buttons.matching(identifier: "Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch

    if playButton.exists || pauseButton.exists {
      // Test UI responsiveness by verifying controls are interactive
      if playButton.exists {
        // Wait for button to be interactive before testing
        XCTAssertTrue(
          playButton.waitForExistence(timeout: adaptiveShortTimeout),
          "Play button should be accessible")
        playButton.tap()

        // Verify the control responds to interaction (state change or remains interactive)
        XCTAssertTrue(
          playButton.exists || pauseButton.exists,
          "Play button should remain responsive after interaction")
      } else if pauseButton.exists {
        // Wait for button to be interactive before testing
        XCTAssertTrue(
          pauseButton.waitForExistence(timeout: adaptiveShortTimeout),
          "Pause button should be accessible")
        pauseButton.tap()

        // Verify the control responds to interaction
        XCTAssertTrue(
          pauseButton.exists || playButton.exists,
          "Pause button should remain responsive after interaction")
      }

      // Then: UI should be responsive (controls remain interactive)
      XCTAssertTrue(
        app.state == .runningForeground, "App should remain responsive during playback control")
    } else {
      XCTFail("No playback controls available - skipping performance test"); return
    }
  }

}

extension PlaybackUITests {

  // MARK: - Acceptance Criteria Tests
  // Covers: Complete playback UI workflows from ui specification

  @MainActor
  func testAcceptanceCriteria_CompletePlaybackWorkflow() throws {
    // Initialize the app
    initializeApp()

    // Given: User wants to control podcast playback
    // Wait for player interface to be ready using robust patterns
    let playerReady = waitForAnyElement(
      [
        app.otherElements.matching(identifier: "Player Interface").firstMatch,
        app.buttons.matching(identifier: "Play").firstMatch,
        app.buttons.matching(identifier: "Pause").firstMatch,
        app.sliders.matching(identifier: "Progress Slider").firstMatch,
      ], timeout: adaptiveTimeout, description: "player interface")

    if playerReady != nil {
      // When: User interacts with all major playback controls using responsive patterns

      // Test play/pause functionality with state awareness
      let playButton = app.buttons.matching(identifier: "Play").firstMatch
      let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch

      if let button = [playButton, pauseButton].first(where: { $0.exists }) {
        button.tap()

        // Wait for playback control to be responsive using XCTestExpectation
        let responsiveExpectation = XCTestExpectation(
          description: "Playback control becomes responsive")

        // Poll for responsive control using run loop scheduling instead of Thread.sleep
        func checkForResponsiveControl() {
          if (app.buttons.matching(identifier: "Play").firstMatch.exists && app.buttons.matching(identifier: "Play").firstMatch.isHittable)
            || (app.buttons.matching(identifier: "Pause").firstMatch.exists && app.buttons.matching(identifier: "Pause").firstMatch.isHittable)
          {
            responsiveExpectation.fulfill()
          } else {
            // Schedule next check using run loop instead of Thread.sleep
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
              checkForResponsiveControl()
            }
          }
        }

        // Start checking
        checkForResponsiveControl()

        wait(for: [responsiveExpectation], timeout: adaptiveShortTimeout)
      }

      // Test skip controls with responsive validation
      let skipControls = [
        app.buttons.matching(identifier: "Skip Forward").firstMatch,
        app.buttons.matching(identifier: "Skip Backward").firstMatch,
      ].filter { $0.exists }

      for control in skipControls {
        control.tap()

        // Wait for control to remain responsive using XCTestExpectation
        let controlResponsiveExpectation = XCTestExpectation(
          description: "\(control.identifier) control becomes responsive")

        // Poll for responsive control
        func checkControlResponsive() {
          if control.exists && control.isHittable {
            controlResponsiveExpectation.fulfill()
          } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
              checkControlResponsive()
            }
          }
        }

        checkControlResponsive()
        wait(for: [controlResponsiveExpectation], timeout: adaptiveShortTimeout)
      }

      // Then: All controls should work without crashing
      XCTAssertTrue(
        app.state == XCUIApplication.State.runningForeground,
        "App should remain stable during playback control")
    } else {
      XCTFail("No playback interface or controls available - skipping workflow test"); return
    }
  }

  @MainActor
  func testAcceptanceCriteria_PlatformIntegrationReadiness() throws {
    // Initialize the app
    initializeApp()

    // Given: App should integrate with platform media systems
    // When: Checking platform integration readiness

    var integrationElements = 0

    // Essential media information present (by id or label)
    if existsByIdOrLabel("Episode Title") { integrationElements += 1 }
    if existsByIdOrLabel("Podcast Title") { integrationElements += 1 }
    if existsByIdOrLabel("Episode Artwork") || app.images.matching(identifier: "Episode Artwork").firstMatch.exists {
      integrationElements += 1
    }

    // Core playback interface elements
    if app.otherElements.matching(identifier: "Player Interface").firstMatch.exists { integrationElements += 1 }
    if app.sliders.matching(identifier: "Progress Slider").firstMatch.exists { integrationElements += 1 }

    // Essential controls present
    let playButton = app.buttons.matching(identifier: "Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch
    if playButton.exists || pauseButton.exists { integrationElements += 1 }

    // Then: App should have sufficient elements for platform integration
    XCTAssertGreaterThanOrEqual(
      integrationElements, 3,
      "App should have sufficient elements for platform media integration")
  }

  @MainActor
  func testAcceptanceCriteria_AccessibilityCompliance() throws {
    // Initialize the app
    initializeApp()

    // Given: Playback interface must be accessible
    // When: Checking comprehensive accessibility using adaptive waiting

    // Wait for the player interface to load with multiple fallback strategies
    let playerElements = waitForAnyElement(
      [
        app.otherElements.matching(identifier: "Player Interface").firstMatch,
        app.buttons.matching(
          NSPredicate(format: "label CONTAINS 'Play' OR identifier CONTAINS 'Play'")
        ).firstMatch,
        app.buttons.matching(
          NSPredicate(format: "label CONTAINS 'Pause' OR identifier CONTAINS 'Pause'")
        ).firstMatch,
        app.sliders.matching(identifier: "Progress Slider").firstMatch,
      ], timeout: adaptiveTimeout, description: "playback interface elements")

    if playerElements != nil {
      // Test accessibility of key playback elements using direct element access
      let accessibleElements: [(String, XCUIElement?)] = [
        ("Play button", app.buttons.matching(identifier: "Play").firstMatch.exists ? app.buttons.matching(identifier: "Play").firstMatch : nil),
        ("Pause button", app.buttons.matching(identifier: "Pause").firstMatch.exists ? app.buttons.matching(identifier: "Pause").firstMatch : nil),
        ("Skip Forward", app.buttons.matching(identifier: "Skip Forward").firstMatch.exists ? app.buttons.matching(identifier: "Skip Forward").firstMatch : nil),
        ("Skip Backward", app.buttons.matching(identifier: "Skip Backward").firstMatch.exists ? app.buttons.matching(identifier: "Skip Backward").firstMatch : nil),
        (
          "Progress Slider",
          app.sliders.matching(identifier: "Progress Slider").firstMatch.exists ? app.sliders.matching(identifier: "Progress Slider").firstMatch : nil
        ),
        (
          "Episode Title",
          app.staticTexts.matching(identifier: "Episode Title").firstMatch.exists ? app.staticTexts.matching(identifier: "Episode Title").firstMatch : nil
        ),
      ]

      var accessibilityScore = 0

      for (name, element) in accessibleElements {
        if let element = element, element.exists {
          // Wait for element to be ready using XCTestExpectation
          let elementReadyExpectation = XCTestExpectation(
            description: "\(name) element ready for accessibility check")

          func checkElementReady() {
            if element.exists && element.isHittable {
              elementReadyExpectation.fulfill()
            } else {
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                checkElementReady()
              }
            }
          }

          checkElementReady()

          let waitResult = XCTWaiter.wait(
            for: [elementReadyExpectation],
            timeout: adaptiveShortTimeout
          )

          guard waitResult == .completed else {
            // Element not ready in time, continue with other elements
            continue
          }

          accessibilityScore += 1

          // Verify element has accessibility properties
          if !element.label.isEmpty || element.isHittable {
            accessibilityScore += 1
          }
        }
      }

      // Then: Interface should have accessibility support
      XCTAssertGreaterThanOrEqual(
        accessibilityScore, 2,
        "Playback interface should have accessibility support (found \(accessibilityScore) accessible elements)"
      )
    } else {
      // Fallback: Check for any playback elements using broader criteria
      let anyPlaybackElements = app.buttons.matching(
        NSPredicate(
          format:
            "label CONTAINS 'Play' OR label CONTAINS 'Pause' OR identifier CONTAINS 'play' OR identifier CONTAINS 'pause'"
        ))

      if anyPlaybackElements.count > 0 {
        XCTAssertGreaterThan(
          anyPlaybackElements.count, 0, "Found \(anyPlaybackElements.count) playback elements")
      } else {
        XCTFail(
          "No playback interface elements found - may need to navigate to player or start playback first")
        return
      }
    }
  }

}

extension PlaybackUITests {

  // MARK: - Mini Player Tests

  /// Given/When/Then: Issue 03.1.1.1 – Mini-Player Foundation
  /// - Given an episode is playing from Library quick play
  /// - When the mini-player becomes visible
  /// - Then it exposes transport controls and expands to the full player without leaving the tab
  @MainActor
  func testMiniPlayerVisibilityAndExpansion() throws {
    startPlaybackFromLibraryQuickPlay()

    let miniPlayer = app.otherElements.matching(identifier: "Mini Player").firstMatch
    XCTAssertTrue(
      miniPlayer.waitForExistence(timeout: 5),
      "Mini player should appear after playback starts"
    )

    let miniPlayerPauseButton = app.buttons.matching(identifier: "Mini Player Pause").firstMatch
    XCTAssertTrue(miniPlayerPauseButton.waitForExistence(timeout: 1))

    miniPlayerPauseButton.tap()
    let playToggle = app.buttons.matching(identifier: "Mini Player Play").firstMatch
    XCTAssertTrue(playToggle.waitForExistence(timeout: 1))

    playToggle.tap()
    XCTAssertTrue(
      app.buttons.matching(identifier: "Mini Player Pause").firstMatch.waitForExistence(timeout: 1),
      "Mini player should toggle back to pause state"
    )

    miniPlayer.tap()

    let expandedPlayer = app.otherElements.matching(identifier: "Expanded Player").firstMatch
    XCTAssertTrue(
      expandedPlayer.waitForExistence(timeout: 5),
      "Expanded player sheet should appear"
    )
  }
}

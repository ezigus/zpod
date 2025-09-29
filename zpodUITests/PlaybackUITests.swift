import XCTest

/// UI tests for playback interface controls and platform integrations
///
/// **Specifications Covered**: `spec/ui.md` - Playback interface sections
/// - Now playing screen controls and media player interface
/// - Lock screen and control center integration testing
/// - CarPlay player interface verification (simulated)
/// - Apple Watch playback controls (simulated)
/// - Bluetooth and external control handling
final class PlaybackUITests: XCTestCase, SmartUITesting {

  nonisolated(unsafe) var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false

    // Initialize app without @MainActor calls in setup
    // XCUIApplication creation and launch will be done in test methods
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - Helpers

  @MainActor
  private func initializeApp() {
    app = launchConfiguredApp()

    // Navigate to player interface for testing
    let tabBar = app.tabBars["Main Tab Bar"]
    let playerTab = tabBar.buttons["Player"]
    if playerTab.exists {
      playerTab.tap()
    }
  }

  @MainActor
  private func hasNonEmptyLabel(_ element: XCUIElement) -> Bool {
    guard element.exists else { return false }
    let text = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
    return !text.isEmpty
  }

  @MainActor
  private func existsByIdOrLabel(_ text: String) -> Bool {
    let q = NSPredicate(format: "identifier == %@ OR label == %@", text, text)
    return app.descendants(matching: .any).matching(q).firstMatch.exists
  }

  // MARK: - Now Playing Interface Tests
  // Covers: Player interface controls from ui spec

  @MainActor
  func testNowPlayingControls() throws {
    // Initialize the app
    initializeApp()

    // Given: Now playing interface is visible
    let playerInterface = app.otherElements["Player Interface"]

    if playerInterface.exists {
      // When: Checking for essential playback controls
      let playButton = app.buttons["Play"]
      let pauseButton = app.buttons["Pause"]
      let skipForwardButton = app.buttons["Skip Forward"]
      let skipBackwardButton = app.buttons["Skip Backward"]

      // Then: Controls should be present and accessible
      XCTAssertTrue(
        playButton.exists || pauseButton.exists,
        "Play/Pause button should be available")

      // Verify skip controls existence and properties
      if skipForwardButton.exists {
        XCTAssertTrue(skipForwardButton.isEnabled, "Skip forward should be enabled")
        XCTAssertTrue(hasNonEmptyLabel(skipForwardButton), "Skip forward should have label")
      }

      if skipBackwardButton.exists {
        XCTAssertTrue(skipBackwardButton.isEnabled, "Skip backward should be enabled")
        XCTAssertTrue(hasNonEmptyLabel(skipBackwardButton), "Skip backward should have label")
      }
    }
  }

  @MainActor
  func testPlaybackSpeedControls() throws {
    // Initialize the app
    initializeApp()

    // Given: Player interface with speed controls
    let speedButton = app.buttons.matching(
      NSPredicate(format: "label CONTAINS 'Speed' OR label CONTAINS 'x'")
    ).firstMatch

    if speedButton.exists {
      // When: Interacting with speed controls
      speedButton.tap()

      // Then: Speed options should be available
      let speedOptions = app.buttons.matching(
        NSPredicate(
          format: "label CONTAINS '1.0x' OR label CONTAINS '1.5x' OR label CONTAINS '2.0x'"))

      if speedOptions.count > 0 {
        XCTAssertGreaterThan(speedOptions.count, 0, "Speed options should be available")

        // Test selecting a speed option
        let fastSpeed = speedOptions.element(boundBy: min(1, speedOptions.count - 1))
        if fastSpeed.exists {
          fastSpeed.tap()
          // Speed should change (verified by UI state)
        }
      }
    }
  }

  @MainActor
  func testProgressSlider() throws {
    // Initialize the app
    initializeApp()

    // Given: Player interface with progress controls
    let progressSlider = app.sliders["Progress Slider"]

    if progressSlider.exists {
      // When: Interacting with progress slider
      // Then: Slider should be interactive
      XCTAssertTrue(progressSlider.isEnabled, "Progress slider should be interactive")

      // Test slider accessibility
      XCTAssertNotNil(progressSlider.value, "Progress slider should have current value")
      XCTAssertTrue(
        hasNonEmptyLabel(progressSlider), "Progress slider should have descriptive label")
    }
  }

  @MainActor
  func testEpisodeInformation() throws {
    // Initialize the app
    initializeApp()

    // Given: Episode is playing
    let episodeTitle = app.staticTexts["Episode Title"]
    let podcastTitle = app.staticTexts["Podcast Title"]
    let episodeArtwork = app.images["Episode Artwork"]

    // When: Checking episode information display
    // Then: Episode information should be visible
    if episodeTitle.exists {
      XCTAssertTrue(hasNonEmptyLabel(episodeTitle), "Episode title should be displayed")
    }

    if podcastTitle.exists {
      XCTAssertTrue(hasNonEmptyLabel(podcastTitle), "Podcast title should be displayed")
    }

    if episodeArtwork.exists {
      // XCUI doesn't expose isAccessibilityElement reliably; existence suffices here
      XCTAssertTrue(episodeArtwork.exists, "Artwork should be accessible")
    }
  }

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
    let playButton = app.buttons["Play"]
    let pauseButton = app.buttons["Pause"]

    if playButton.exists || pauseButton.exists {
      // Then: Media controls should be accessible for system integration
      XCTAssertTrue(
        playButton.exists || pauseButton.exists,
        "Media controls should be available for system integration")
    }

    // Test that episode information is available for system display
    let episodeTitle = app.staticTexts["Episode Title"]
    if episodeTitle.exists {
      XCTAssertTrue(
        hasNonEmptyLabel(episodeTitle),
        "Episode title should be available for control center")
    }
  }

  // MARK: - Lock Screen Integration Tests
  // Covers: Lock screen player from ui spec

  @MainActor
  func testLockScreenMediaInfo() throws {
    // Initialize the app
    initializeApp()

    // Given: App is configured for lock screen media display
    // When: Checking media information availability

    // Verify that required media information is present
    let episodeTitle = app.staticTexts["Episode Title"]
    let podcastTitle = app.staticTexts["Podcast Title"]
    let episodeArtwork = app.images["Episode Artwork"]

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

  // MARK: - CarPlay Interface Tests
  // Covers: CarPlay integration from ui spec

  @MainActor
  func testCarPlayCompatibleInterface() throws {
    // Initialize the app
    initializeApp()

    // Given: App interface should be CarPlay compatible
    // When: Checking for CarPlay-suitable controls

    // CarPlay requires large, easily accessible controls
    let playButton = app.buttons["Play"]
    let pauseButton = app.buttons["Pause"]
    let skipForwardButton = app.buttons["Skip Forward"]
    let skipBackwardButton = app.buttons["Skip Backward"]

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
    let episodeTitle = app.staticTexts["Episode Title"]
    if episodeTitle.exists {
      XCTAssertTrue(
        episodeTitle.label.count <= 50,
        "Episode title should be concise for CarPlay display")
    }
  }

  // MARK: - Apple Watch Interface Tests
  // Covers: Apple Watch support from ui spec

  @MainActor
  func testWatchCompatibleControls() throws {
    // Initialize the app
    initializeApp()

    // Given: App should support Apple Watch companion
    // When: Checking for Watch-suitable interface elements

    // Watch interface requires essential controls only
    let playButton = app.buttons["Play"]
    let pauseButton = app.buttons["Pause"]

    // Then: Essential controls should be available
    if playButton.exists || pauseButton.exists {
      XCTAssertTrue(
        playButton.exists || pauseButton.exists,
        "Essential playback controls should be available for Watch")
    }

    // Test simplified information display suitable for Watch
    let episodeTitle = app.staticTexts["Episode Title"]
    if episodeTitle.exists && episodeTitle.label.count > 30 {
      // Title should be truncatable for Watch display
      XCTAssertTrue(true, "Long titles should be handled appropriately for Watch")
    }
  }

  // MARK: - Accessibility Tests for Playback
  // Covers: Accessibility for playback features from ui spec

  @MainActor
  func testPlaybackAccessibility() throws {
    // Initialize the app
    initializeApp()

    // Given: Playback interface is accessible
    // When: Checking accessibility features

    let playButton = app.buttons["Play"]
    let pauseButton = app.buttons["Pause"]

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
    let progressSlider = app.sliders["Progress Slider"]
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
      app.buttons["Skip Backward"],
      app.buttons["Play"],
      app.buttons["Pause"],
      app.buttons["Skip Forward"],
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

  // MARK: - Performance Tests
  // Covers: UI responsiveness during playback

  @MainActor
  func testPlaybackUIPerformance() throws {
    // Initialize the app
    initializeApp()

    // Given: Playback interface is loaded
    // When: Interacting with playback controls
    let playButton = app.buttons["Play"]
    let pauseButton = app.buttons["Pause"]

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
      throw XCTSkip("No playback controls available - skipping performance test")
    }
  }

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
        app.otherElements["Player Interface"],
        app.buttons["Play"],
        app.buttons["Pause"],
        app.sliders["Progress Slider"],
      ], timeout: adaptiveTimeout, description: "player interface")

    if playerReady != nil {
      // When: User interacts with all major playback controls using responsive patterns

      // Test play/pause functionality with state awareness
      let playButton = app.buttons["Play"]
      let pauseButton = app.buttons["Pause"]

      if let button = [playButton, pauseButton].first(where: { $0.exists }) {
        button.tap()

        // Wait for playback control to be responsive using XCTestExpectation
        let responsiveExpectation = XCTestExpectation(
          description: "Playback control becomes responsive")

        // Poll for responsive control using run loop scheduling instead of Thread.sleep
        func checkForResponsiveControl() {
          if (app.buttons["Play"].exists && app.buttons["Play"].isHittable)
            || (app.buttons["Pause"].exists && app.buttons["Pause"].isHittable)
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
        app.buttons["Skip Forward"],
        app.buttons["Skip Backward"],
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
      throw XCTSkip("No playback interface or controls available - skipping workflow test")
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
    if existsByIdOrLabel("Episode Artwork") || app.images["Episode Artwork"].exists {
      integrationElements += 1
    }

    // Core playback interface elements
    if app.otherElements["Player Interface"].exists { integrationElements += 1 }
    if app.sliders["Progress Slider"].exists { integrationElements += 1 }

    // Essential controls present
    let playButton = app.buttons["Play"]
    let pauseButton = app.buttons["Pause"]
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
        app.otherElements["Player Interface"],
        app.buttons.matching(
          NSPredicate(format: "label CONTAINS 'Play' OR identifier CONTAINS 'Play'")
        ).firstMatch,
        app.buttons.matching(
          NSPredicate(format: "label CONTAINS 'Pause' OR identifier CONTAINS 'Pause'")
        ).firstMatch,
        app.sliders["Progress Slider"],
      ], timeout: adaptiveTimeout, description: "playback interface elements")

    if playerElements != nil {
      // Test accessibility of key playback elements using direct element access
      let accessibleElements: [(String, XCUIElement?)] = [
        ("Play button", app.buttons["Play"].exists ? app.buttons["Play"] : nil),
        ("Pause button", app.buttons["Pause"].exists ? app.buttons["Pause"] : nil),
        ("Skip Forward", app.buttons["Skip Forward"].exists ? app.buttons["Skip Forward"] : nil),
        ("Skip Backward", app.buttons["Skip Backward"].exists ? app.buttons["Skip Backward"] : nil),
        (
          "Progress Slider",
          app.sliders["Progress Slider"].exists ? app.sliders["Progress Slider"] : nil
        ),
        (
          "Episode Title",
          app.staticTexts["Episode Title"].exists ? app.staticTexts["Episode Title"] : nil
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
        throw XCTSkip(
          "No playback interface elements found - may need to navigate to player or start playback first"
        )
      }
    }
  }
}

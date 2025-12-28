import XCTest

/// UI tests for player accessibility and Dynamic Type behavior.
///
/// Validates Issue 03.1.1.4 acceptance criteria:
/// - VoiceOver labels/hints for mini/expanded player controls.
/// - Dynamic Type scaling at accessibility sizes.
final class PlayerAccessibilityTests: XCTestCase, SmartUITesting {

  nonisolated(unsafe) var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    disableWaitingForIdleIfNeeded()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - Helpers

  @MainActor
  private func launchApp(
    environmentOverrides: [String: String] = [:],
    launchArguments: [String] = []
  ) {
    app = launchConfiguredApp(
      environmentOverrides: environmentOverrides,
      launchArguments: launchArguments
    )
  }

  @MainActor
  private func navigateToLibraryTab() {
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
    XCTAssertTrue(libraryTab.waitForExistence(timeout: adaptiveShortTimeout), "Library tab should exist")
    libraryTab.tap()
  }

  @MainActor
  private func navigateToPodcast(_ podcastIdentifier: String = "Podcast-swift-talk") {
    let libraryLoaded = waitForContentToLoad(
      containerIdentifier: "Podcast Cards Container",
      timeout: adaptiveTimeout
    )
    guard libraryLoaded else {
      XCTFail("Library content failed to load")
      return
    }

    let podcastButton = app.buttons.matching(identifier: podcastIdentifier).firstMatch
    XCTAssertTrue(
      podcastButton.waitForExistence(timeout: adaptiveShortTimeout),
      "Podcast '\(podcastIdentifier)' should exist"
    )

    // If button isn't hittable (e.g., at large accessibility text sizes), try coordinate tap
    if !waitForElementToBeHittable(podcastButton, timeout: adaptiveShortTimeout, description: "Podcast button") {
      // Tap at the center of the button's frame using coordinates
      podcastButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    } else {
      podcastButton.tap()
    }
  }

  @MainActor
  private func waitForEpisodeList() -> Bool {
    waitForContentToLoad(
      containerIdentifier: "Episode List View",
      itemIdentifiers: ["Episode-st-001"],
      timeout: adaptiveTimeout
    )
  }

  @MainActor
  private func startPlaybackFromQuickPlay() {
    navigateToLibraryTab()
    navigateToPodcast()
    XCTAssertTrue(waitForEpisodeList(), "Episode list should load")
    tapQuickPlayButton(in: app, timeout: adaptiveTimeout)

    let miniPlayer = miniPlayerElement(in: app)
    XCTAssertTrue(
      miniPlayer.waitForExistence(timeout: adaptiveTimeout),
      "Mini player should appear after quick play"
    )
  }

  @MainActor
  private func openExpandedPlayer() {
    let miniPlayer = miniPlayerElement(in: app)
    XCTAssertTrue(miniPlayer.waitForExistence(timeout: adaptiveTimeout), "Mini player should appear")
    if miniPlayer.isHittable {
      miniPlayer.tap()
    } else {
      miniPlayer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    let expandedPlayer = app.otherElements.matching(identifier: "Expanded Player").firstMatch
    if !expandedPlayer.waitForExistence(timeout: adaptiveShortTimeout) {
      if miniPlayer.isHittable {
        miniPlayer.tap()
      } else {
        miniPlayer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
      }
    }

    XCTAssertTrue(
      expandedPlayer.waitForExistence(timeout: adaptiveTimeout),
      "Expanded player should appear after tapping mini player"
    )
  }

  // MARK: - Tests

  @MainActor
  func testExpandedPlayerAccessibilityLabels() throws {
    launchApp()
    startPlaybackFromQuickPlay()
    openExpandedPlayer()

    let episodeTitle = app.staticTexts.matching(identifier: "Expanded Player Episode Title").firstMatch
    XCTAssertTrue(
      episodeTitle.waitForExistence(timeout: adaptiveShortTimeout),
      "Expanded player episode title should be accessible"
    )
    XCTAssertTrue(hasNonEmptyLabel(episodeTitle), "Expanded episode title should have a label")

    let podcastTitle = app.staticTexts.matching(identifier: "Expanded Player Podcast Title").firstMatch
    XCTAssertTrue(
      podcastTitle.waitForExistence(timeout: adaptiveShortTimeout),
      "Expanded player podcast title should be accessible"
    )
    XCTAssertTrue(hasNonEmptyLabel(podcastTitle), "Expanded podcast title should have a label")

    let skipBackward = app.buttons.matching(identifier: "Expanded Player Skip Backward").firstMatch
    let skipForward = app.buttons.matching(identifier: "Expanded Player Skip Forward").firstMatch
    XCTAssertTrue(
      skipBackward.waitForExistence(timeout: adaptiveShortTimeout),
      "Expanded player skip backward should be accessible"
    )
    XCTAssertTrue(
      skipForward.waitForExistence(timeout: adaptiveShortTimeout),
      "Expanded player skip forward should be accessible"
    )
    XCTAssertEqual(skipBackward.label, "Skip backward 15 seconds")
    XCTAssertEqual(skipForward.label, "Skip forward 30 seconds")

    let playButton = app.buttons.matching(identifier: "Expanded Player Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Expanded Player Pause").firstMatch
    let playOrPause = waitForAnyElement(
      [playButton, pauseButton],
      timeout: adaptiveShortTimeout,
      description: "Expanded player play/pause",
      failOnTimeout: false
    )
    XCTAssertNotNil(playOrPause, "Expanded player play/pause button should be accessible")
    if let playOrPause {
      XCTAssertTrue(hasNonEmptyLabel(playOrPause), "Play/pause should have a VoiceOver label")
    }

    let progressSlider = app.sliders.matching(identifier: "Progress Slider").firstMatch
    XCTAssertTrue(
      progressSlider.waitForExistence(timeout: adaptiveShortTimeout),
      "Expanded player progress slider should be accessible"
    )
    XCTAssertEqual(progressSlider.label, "Progress Slider")
  }

  @MainActor
  func testDynamicTypeAccessibilitySizeKeepsMiniPlayerVisible() throws {
    launchApp(launchArguments: [
      "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryAccessibilityXXXL",
    ])
    startPlaybackFromQuickPlay()

    let miniPlayer = miniPlayerElement(in: app)
    XCTAssertTrue(miniPlayer.exists, "Mini player should remain visible at large type sizes")

    let skipBackward = app.buttons.matching(identifier: "Mini Player Skip Backward").firstMatch
    let skipForward = app.buttons.matching(identifier: "Mini Player Skip Forward").firstMatch
    XCTAssertTrue(
      skipBackward.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player skip backward should exist at large type sizes"
    )
    XCTAssertTrue(
      skipForward.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player skip forward should exist at large type sizes"
    )
    XCTAssertTrue(skipBackward.isHittable, "Mini player skip backward should be hittable")
    XCTAssertTrue(skipForward.isHittable, "Mini player skip forward should be hittable")
  }

  @MainActor
  func testDynamicTypeAccessibilitySizeKeepsExpandedPlayerVisible() throws {
    launchApp(
      environmentOverrides: ["UITEST_FORCE_EXPANDED_PLAYER": "1"],
      launchArguments: [
        "-UIPreferredContentSizeCategoryName",
        "UICTContentSizeCategoryAccessibilityXXXL",
      ]
    )

    let expandedPlayer = app.otherElements.matching(identifier: "Expanded Player").firstMatch
    XCTAssertTrue(
      expandedPlayer.waitForExistence(timeout: adaptiveTimeout),
      "Expanded player should be visible at large type sizes"
    )

    let skipBackward = app.buttons.matching(identifier: "Expanded Player Skip Backward").firstMatch
    let skipForward = app.buttons.matching(identifier: "Expanded Player Skip Forward").firstMatch
    XCTAssertTrue(
      skipBackward.waitForExistence(timeout: adaptiveShortTimeout),
      "Skip backward should exist at large type sizes"
    )
    XCTAssertTrue(
      skipForward.waitForExistence(timeout: adaptiveShortTimeout),
      "Skip forward should exist at large type sizes"
    )
    XCTAssertTrue(skipBackward.isHittable, "Skip backward should be hittable at large type sizes")
    XCTAssertTrue(skipForward.isHittable, "Skip forward should be hittable at large type sizes")

    let playButton = app.buttons.matching(identifier: "Expanded Player Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Expanded Player Pause").firstMatch
    let playOrPause = waitForAnyElement(
      [playButton, pauseButton],
      timeout: adaptiveShortTimeout,
      description: "Expanded player play/pause",
      failOnTimeout: false
    )
    XCTAssertNotNil(playOrPause, "Play/pause should exist at large type sizes")
    if let playOrPause {
      XCTAssertTrue(playOrPause.isHittable, "Play/pause should be hittable at large type sizes")
    }
  }
}

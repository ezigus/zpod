import XCTest

/// UI tests for mini-player persistence and accessibility.
///
/// Validates Issue 03.1.1.1 acceptance criteria:
/// - Mini-player persists across tab switches and navigation changes.
/// - Quick play from Library triggers playback and mini-player visibility.
/// - VoiceOver labels are present on mini-player controls.
final class MiniPlayerPersistenceTests: XCTestCase, SmartUITesting {

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
  private func launchApp() {
    app = launchConfiguredApp()
  }

  @MainActor
  private func navigateToLibraryTab() {
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
    guard waitForElement(libraryTab, timeout: adaptiveShortTimeout, description: "Library tab")
    else { return }
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
    guard
      waitForElement(
        podcastButton,
        timeout: adaptiveTimeout,
        description: "Podcast \(podcastIdentifier)"
      )
    else { return }
    podcastButton.tap()
  }

  @MainActor
  @discardableResult
  private func waitForEpisodeList() -> Bool {
    waitForContentToLoad(
      containerIdentifier: "Episode List View",
      itemIdentifiers: ["Episode-st-001"],
      timeout: adaptiveTimeout
    )
  }

  @MainActor
  // MARK: - Tests

  @MainActor
  func testMiniPlayerPersistsAcrossTabSwitches() throws {
    launchApp()
    navigateToLibraryTab()
    navigateToPodcast()
    XCTAssertTrue(waitForEpisodeList(), "Episode list should load")
    tapQuickPlayButton(in: app, timeout: adaptiveTimeout)

    let miniPlayer = miniPlayerElement(in: app)
    XCTAssertTrue(
      miniPlayer.waitForExistence(timeout: adaptiveTimeout),
      "Mini player should appear after quick play"
    )

    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    let settingsTab = tabBar.buttons.matching(identifier: "Settings").firstMatch
    XCTAssertTrue(
      settingsTab.waitForExistence(timeout: adaptiveShortTimeout),
      "Settings tab should exist"
    )
    settingsTab.tap()
    XCTAssertTrue(
      miniPlayer.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player should persist after switching tabs"
    )

    let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
    XCTAssertTrue(
      libraryTab.waitForExistence(timeout: adaptiveShortTimeout),
      "Library tab should exist"
    )
    libraryTab.tap()
    XCTAssertTrue(
      miniPlayer.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player should persist when returning to Library"
    )
  }

  @MainActor
  func testMiniPlayerPersistsAcrossNavigation() throws {
    launchApp()
    navigateToLibraryTab()
    navigateToPodcast()
    XCTAssertTrue(waitForEpisodeList(), "Episode list should load")
    tapQuickPlayButton(in: app, timeout: adaptiveTimeout)

    let miniPlayer = miniPlayerElement(in: app)
    XCTAssertTrue(
      miniPlayer.waitForExistence(timeout: adaptiveTimeout),
      "Mini player should appear after quick play"
    )

    let backButton = app.navigationBars.buttons.firstMatch
    if backButton.waitForExistence(timeout: adaptiveShortTimeout) {
      backButton.tap()
    }

    let podcastListLoaded = waitForContentToLoad(
      containerIdentifier: "Podcast Cards Container",
      timeout: adaptiveTimeout
    )
    XCTAssertTrue(podcastListLoaded, "Podcast list should load after navigating back")
    XCTAssertTrue(
      miniPlayer.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player should persist after navigating back"
    )

    navigateToPodcast()
    XCTAssertTrue(waitForEpisodeList(), "Episode list should load after re-entering podcast")
    XCTAssertTrue(
      miniPlayer.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player should persist after navigating forward"
    )
  }

  @MainActor
  func testQuickPlayShowsMiniPlayerWithoutLeavingEpisodeList() throws {
    launchApp()
    navigateToLibraryTab()
    navigateToPodcast()
    XCTAssertTrue(waitForEpisodeList(), "Episode list should load")
    tapQuickPlayButton(in: app, timeout: adaptiveTimeout)

    let episodeList = app.otherElements.matching(identifier: "Episode List View").firstMatch
    XCTAssertTrue(
      episodeList.waitForExistence(timeout: adaptiveShortTimeout),
      "Episode list should remain visible after quick play"
    )

    let miniPlayer = miniPlayerElement(in: app)
    XCTAssertTrue(
      miniPlayer.waitForExistence(timeout: adaptiveTimeout),
      "Mini player should appear after quick play"
    )
  }

  @MainActor
  func testMiniPlayerAccessibilityLabels() throws {
    launchApp()
    navigateToLibraryTab()
    navigateToPodcast()
    XCTAssertTrue(waitForEpisodeList(), "Episode list should load")
    tapQuickPlayButton(in: app, timeout: adaptiveTimeout)

    let miniPlayer = miniPlayerElement(in: app)
    XCTAssertTrue(
      miniPlayer.waitForExistence(timeout: adaptiveTimeout),
      "Mini player should appear before checking accessibility"
    )

    let episodeTitle = app.staticTexts.matching(identifier: "Mini Player Episode Title").firstMatch
    XCTAssertTrue(
      episodeTitle.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player episode title should be accessible"
    )
    XCTAssertTrue(hasNonEmptyLabel(episodeTitle), "Episode title should have a label")

    let skipBackward = app.buttons.matching(identifier: "Mini Player Skip Backward").firstMatch
    let skipForward = app.buttons.matching(identifier: "Mini Player Skip Forward").firstMatch
    XCTAssertTrue(
      skipBackward.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player skip backward should be accessible"
    )
    XCTAssertTrue(
      skipForward.waitForExistence(timeout: adaptiveShortTimeout),
      "Mini player skip forward should be accessible"
    )
    XCTAssertEqual(skipBackward.label, "Skip backward")
    XCTAssertEqual(skipForward.label, "Skip forward")

    let playButton = app.buttons.matching(identifier: "Mini Player Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Mini Player Pause").firstMatch
    let playOrPause = waitForAnyElement(
      [playButton, pauseButton],
      timeout: adaptiveShortTimeout,
      description: "Mini player play/pause",
      failOnTimeout: false
    )
    XCTAssertNotNil(playOrPause, "Mini player play/pause button should be accessible")
    if let playOrPause {
      XCTAssertTrue(hasNonEmptyLabel(playOrPause), "Play/pause should have a VoiceOver label")
    }
  }
}

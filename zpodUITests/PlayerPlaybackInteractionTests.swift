import XCTest

/// UI tests for player playback interactions.
///
/// Validates quick play and mini-player interactions against Issue 03.1.1.1.
final class PlayerPlaybackInteractionTests: XCTestCase, SmartUITesting {

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

  /// Navigate to Library tab
  @MainActor
  private func navigateToLibraryTab() {
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
    XCTAssertTrue(libraryTab.waitForExistence(timeout: adaptiveTimeout), "Library tab should exist")
    libraryTab.tap()
  }

  /// Navigate to a podcast from Library (assumes Library tab is active)
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
    podcastButton.tap()
  }

  /// Wait for episode list to load
  @MainActor
  private func waitForEpisodeList() -> Bool {
    waitForContentToLoad(
      containerIdentifier: "Episode List View",
      itemIdentifiers: ["Episode-st-001"],
      timeout: adaptiveTimeout
    )
  }

  /// Quick play a seeded episode
  @MainActor
  private func quickPlayEpisode(_ episodeIdentifier: String = "Episode-st-001") {
    let rawEpisodeId = episodeIdentifier.hasPrefix("Episode-")
      ? String(episodeIdentifier.dropFirst("Episode-".count))
      : episodeIdentifier
    let primaryQuickPlayButton = app.buttons
      .matching(identifier: "Episode-\(rawEpisodeId)-QuickPlay")
      .firstMatch
    let fallbackQuickPlayButton = app.buttons
      .matching(identifier: "Episode-\(rawEpisodeId)")
      .matching(NSPredicate(format: "label == 'Quick play'"))
      .firstMatch
    guard
      let quickPlayButton = waitForAnyElement(
        [primaryQuickPlayButton, fallbackQuickPlayButton],
        timeout: adaptiveShortTimeout,
        description: "Quick play button",
        failOnTimeout: true
      )
    else { return }
    quickPlayButton.tap()
  }

  @MainActor
  private func miniPlayerElement() -> XCUIElement {
    app.otherElements.matching(identifier: "Mini Player").firstMatch
  }

  // MARK: - Playback Interaction Tests

  /// Test: Quick play starts playback and shows mini-player controls
  @MainActor
  func testQuickPlayStartsPlayback() throws {
    launchApp()
    navigateToLibraryTab()
    navigateToPodcast()

    XCTAssertTrue(waitForEpisodeList(), "Episode list should load")
    quickPlayEpisode()

    let miniPlayer = miniPlayerElement()
    XCTAssertTrue(miniPlayer.waitForExistence(timeout: adaptiveTimeout), "Mini player should appear")

    let playButton = app.buttons.matching(identifier: "Mini Player Play").firstMatch
    let pauseButton = app.buttons.matching(identifier: "Mini Player Pause").firstMatch
    let playOrPause = waitForAnyElement(
      [playButton, pauseButton],
      timeout: adaptiveShortTimeout,
      description: "Mini player play/pause",
      failOnTimeout: false
    )
    XCTAssertNotNil(playOrPause, "Mini player play/pause control should be available")
  }

  /// Test: Mini-player remains visible after navigating back to the podcast list
  @MainActor
  func testMiniPlayerAppearsAfterPlayback() throws {
    launchApp()
    navigateToLibraryTab()
    navigateToPodcast()

    XCTAssertTrue(waitForEpisodeList(), "Episode list should load")
    quickPlayEpisode()

    let miniPlayer = miniPlayerElement()
    XCTAssertTrue(miniPlayer.waitForExistence(timeout: adaptiveTimeout), "Mini player should appear")

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
      "Mini player should remain visible after navigation"
    )
  }

  /// Test: Tapping mini-player expands to full player
  @MainActor
  func testMiniPlayerExpandsToFullPlayer() throws {
    launchApp()
    navigateToLibraryTab()
    navigateToPodcast()

    XCTAssertTrue(waitForEpisodeList(), "Episode list should load")
    quickPlayEpisode()

    let miniPlayer = miniPlayerElement()
    XCTAssertTrue(miniPlayer.waitForExistence(timeout: adaptiveTimeout), "Mini player should appear")
    miniPlayer.tap()

    let expandedPlayer = app.otherElements.matching(identifier: "Expanded Player").firstMatch
    XCTAssertTrue(
      expandedPlayer.waitForExistence(timeout: adaptiveTimeout),
      "Expanded player should appear after tapping mini player"
    )
  }
}

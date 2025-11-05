import XCTest

/// UI tests for player navigation flow.
///
/// Validates navigation paths:
/// - Library → Podcast
/// - Podcast → Episode List
/// - Episode List → Episode Detail
/// - Episode Detail presence and structure
///
/// Each test validates one specific navigation step with minimal setup.
final class PlayerNavigationTests: XCTestCase, SmartUITesting {

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
    let libraryTab = app.tabBars["Main Tab Bar"].buttons["Library"]
    XCTAssertTrue(libraryTab.waitForExistence(timeout: adaptiveTimeout), "Library tab should exist")
    libraryTab.tap()
  }

  /// Navigate to a podcast from Library (assumes Library tab is active)
  @MainActor
  private func navigateToPodcast(_ podcastIdentifier: String = "Podcast-swift-talk") {
    // Wait for podcast container
    guard
      let podcastContainer = findContainerElement(in: app, identifier: "Podcast Cards Container")
    else {
      XCTFail("Could not find podcast cards container")
      return
    }
    XCTAssertTrue(podcastContainer.exists, "Podcast container should exist")

    // Wait for specific podcast
    let podcastButton = app.buttons[podcastIdentifier]
    XCTAssertTrue(
      podcastButton.waitForExistence(timeout: adaptiveShortTimeout),
      "Podcast '\(podcastIdentifier)' should exist")
    podcastButton.tap()
  }

  /// Navigate to an episode from episode list (assumes episode list is active)
  @MainActor
  private func navigateToEpisode(_ episodeIdentifier: String = "Episode-st-001") {
    // Wait for episode list
    guard let episodeList = findContainerElement(in: app, identifier: "Episode List View") else {
      XCTFail("Could not find episode list container")
      return
    }
    XCTAssertTrue(episodeList.exists, "Episode list should exist")

    // Wait for specific episode
    let episodeButton = app.buttons[episodeIdentifier]
    XCTAssertTrue(
      episodeButton.waitForExistence(timeout: adaptiveShortTimeout),
      "Episode '\(episodeIdentifier)' should exist")
    episodeButton.tap()
  }

  /// Wait for episode detail to load (flexible detection)
  @MainActor
  private func waitForEpisodeDetail() -> Bool {
    // Use waitUntil to check for any play button variant
    waitUntil(timeout: adaptiveShortTimeout) {
      let playButtons = self.app.buttons.matching(
        NSPredicate(format: "label CONTAINS[c] 'play' OR identifier CONTAINS[c] 'play'")
      )
      return playButtons.count > 0
    }
  }

  // MARK: - Navigation Tests

  /// Test: Navigate from Library to podcast detail
  @MainActor
  func testNavigateFromLibraryToPodcast() throws {
    launchApp()
    navigateToLibraryTab()
    navigateToPodcast()

    // Verify we're on the episode list
    let episodeList = findContainerElement(in: app, identifier: "Episode List View")
    XCTAssertNotNil(episodeList, "Episode list should be visible after navigating to podcast")
  }

  /// Test: Navigate to episode detail
  @MainActor
  func testNavigateToEpisodeDetail() throws {
    launchApp()
    navigateToLibraryTab()
    navigateToPodcast()
    navigateToEpisode()

    XCTAssertTrue(waitForEpisodeDetail(), "Episode detail should load")
  }

  /// Test: Episode detail has play button
  @MainActor
  func testEpisodeDetailHasPlayButton() throws {
    launchApp()
    navigateToLibraryTab()
    navigateToPodcast()
    navigateToEpisode()

    XCTAssertTrue(waitForEpisodeDetail(), "Episode detail should load")

    // Verify play button is present
    let playButton = app.buttons.matching(
      NSPredicate(format: "label CONTAINS[c] 'play' OR identifier CONTAINS[c] 'play'")
    ).firstMatch
    XCTAssertTrue(
      playButton.waitForExistence(timeout: adaptiveShortTimeout), "Play button should exist")
  }
}

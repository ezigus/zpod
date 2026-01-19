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
final class PlayerNavigationTests: IsolatedUITestCase {

  override func setUpWithError() throws {
    try super.setUpWithError()
    disableWaitingForIdleIfNeeded()
  }

  // MARK: - Helpers

  @MainActor
  private func launchAndOpenLibrary() {
    app = launchConfiguredApp()
    let tabs = TabBarNavigation(app: app)
    XCTAssertTrue(tabs.navigateToLibrary(), "Library tab should be reachable after launch")
  }

  @MainActor
  @discardableResult
  private func openEpisodeFromList() -> PlayerScreen {
    let library = LibraryScreen(app: app)
    XCTAssertTrue(library.selectEpisode("Episode-st-001"), "Episode should exist in the list")

    let player = PlayerScreen(app: app)
    XCTAssertTrue(player.waitForPlayerInterface(), "Player interface should appear after episode tap")
    return player
  }

  @MainActor
  private func openEpisodeList() {
    let library = LibraryScreen(app: app)
    XCTAssertTrue(library.waitForLibraryContent(), "Library content should load")
    XCTAssertTrue(library.selectPodcast("Podcast-swift-talk"), "Podcast should be selectable")
  }

  // MARK: - Navigation Tests

  /// Test: Navigate from Library to podcast detail
  @MainActor
  func testNavigateFromLibraryToPodcast() throws {
    launchAndOpenLibrary()
    let library = LibraryScreen(app: app)
    XCTAssertTrue(library.waitForLibraryContent(), "Library content should load")
    XCTAssertTrue(library.selectPodcast("Podcast-swift-talk"), "Podcast should be selectable")
    XCTAssertTrue(library.waitForEpisodeList(), "Episode list should appear after selecting a podcast")
  }

  /// Test: Navigate to episode detail
  @MainActor
  func testNavigateToEpisodeDetail() throws {
    launchAndOpenLibrary()
    openEpisodeList()
    openEpisodeFromList()
  }

  /// Test: Episode detail has play button
  @MainActor
  func testEpisodeDetailHasPlayButton() throws {
    launchAndOpenLibrary()
    openEpisodeList()
    let player = openEpisodeFromList()

    let playButton = player.waitForPlayButton(timeout: adaptiveShortTimeout)
    XCTAssertNotNil(playButton, "Play button should be present in the player interface")
  }
}

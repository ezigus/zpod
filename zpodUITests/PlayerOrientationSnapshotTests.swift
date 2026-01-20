import XCTest

/// UI tests for player layout in different orientations with snapshot capture.
///
/// Validates layout adaptation and captures screenshots in:
/// - Portrait orientation
/// - Landscape left orientation
/// - Landscape right orientation
///
/// Screenshots are attached to test results for visual regression comparison.
final class PlayerOrientationSnapshotTests: IsolatedUITestCase {

  override func tearDownWithError() throws {
    // Reset orientation back to portrait before base class cleanup
    Task { @MainActor in
      XCUIDevice.shared.orientation = .portrait
    }
    try super.tearDownWithError()
  }

  // MARK: - Helper Methods

  /// Navigate to Library tab
  @MainActor
  private func navigateToLibraryTab() {
    let libraryTab = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch.buttons.matching(identifier: "Library").firstMatch
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
    let podcastButton = app.buttons.matching(identifier: podcastIdentifier).firstMatch
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
    let episodeButton = app.buttons.matching(identifier: episodeIdentifier).firstMatch
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

  // MARK: - Orientation & Snapshot Tests

  /// Test: Episode detail in portrait orientation
  @MainActor
  func testEpisodeDetailPortraitOrientation() throws {
    app = launchConfiguredApp()

    // Explicitly set portrait orientation
    XCUIDevice.shared.orientation = .portrait

    navigateToLibraryTab()
    navigateToPodcast()
    navigateToEpisode()

    XCTAssertTrue(waitForEpisodeDetail(), "Episode detail should load")

    // Take snapshot
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "episode-detail-portrait"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  /// Test: Episode detail in landscape left orientation
  @MainActor
  func testEpisodeDetailLandscapeLeftOrientation() throws {
    app = launchConfiguredApp()
    navigateToLibraryTab()
    navigateToPodcast()
    navigateToEpisode()

    XCTAssertTrue(waitForEpisodeDetail(), "Episode detail should load")

    // Rotate to landscape left
    XCUIDevice.shared.orientation = .landscapeLeft

    // Wait a moment for rotation animation
    _ = app.wait(for: .runningForeground, timeout: 2)

    // Verify play button still visible after rotation
    let playButton = app.buttons.matching(
      NSPredicate(format: "label CONTAINS[c] 'play' OR identifier CONTAINS[c] 'play'")
    ).firstMatch
    XCTAssertTrue(playButton.exists, "Play button should remain visible in landscape")

    // Take snapshot
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "episode-detail-landscape-left"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  /// Test: Episode detail in landscape right orientation
  @MainActor
  func testEpisodeDetailLandscapeRightOrientation() throws {
    app = launchConfiguredApp()
    navigateToLibraryTab()
    navigateToPodcast()
    navigateToEpisode()

    XCTAssertTrue(waitForEpisodeDetail(), "Episode detail should load")

    // Rotate to landscape right
    XCUIDevice.shared.orientation = .landscapeRight

    // Wait a moment for rotation animation
    _ = app.wait(for: .runningForeground, timeout: 2)

    // Verify play button still visible after rotation
    let playButton = app.buttons.matching(
      NSPredicate(format: "label CONTAINS[c] 'play' OR identifier CONTAINS[c] 'play'")
    ).firstMatch
    XCTAssertTrue(playButton.exists, "Play button should remain visible in landscape")

    // Take snapshot
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "episode-detail-landscape-right"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

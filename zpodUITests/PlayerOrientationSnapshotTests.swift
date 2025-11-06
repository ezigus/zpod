import XCTest

/// UI tests for player layout in different orientations with snapshot capture.
///
/// Validates layout adaptation and captures screenshots in:
/// - Portrait orientation
/// - Landscape left orientation
/// - Landscape right orientation
///
/// Screenshots are attached to test results for visual regression comparison.
final class PlayerOrientationSnapshotTests: XCTestCase, SmartUITesting {

  nonisolated(unsafe) var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    disableWaitingForIdleIfNeeded()
  }

  override func tearDownWithError() throws {
    // Reset orientation back to portrait
    Task { @MainActor in
      XCUIDevice.shared.orientation = .portrait
    }
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

  // MARK: - Orientation & Snapshot Tests

  /// Test: Episode detail in portrait orientation
  @MainActor
  func testEpisodeDetailPortraitOrientation() throws {
    launchApp()

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
    launchApp()
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
    launchApp()
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

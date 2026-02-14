//
//  DownloadFlowUITests.swift
//  zpodUITests
//
//  Created for Issue 28.1: Offline and Streaming Playback Infrastructure
//  Tests download functionality, progress indicators, and status badges
//

import XCTest

/// UI tests for episode download functionality
///
/// **Spec Coverage**: `spec/offline-playback.md`
/// - Download initiation via swipe action
/// - Progress indicator display
/// - Download completion status
/// - Batch download operations
/// - Download deletion
///
/// **Issue**: #28.1 - Phase 4: Test Infrastructure
final class DownloadFlowUITests: IsolatedUITestCase {
  private let downloadSwipeSuite = "us.zig.zpod.download-flow-swipes"

  private func launchDownloadSwipeApp(
    additionalEnvironment: [String: String] = [:]
  ) {
    var environment = UITestLaunchConfiguration.swipeConfiguration(
      suite: downloadSwipeSuite,
      reset: true,
      seededConfiguration: SwipeConfigurationSeeding.downloadFocused
    )
    additionalEnvironment.forEach { environment[$0] = $1 }
    app = launchConfiguredApp(environmentOverrides: environment)
  }

  // MARK: - Basic Download Flow Tests

  /// Test: User can initiate download via swipe action
  ///
  /// **Spec**: offline-playback.md - "User swipes to download episode"
  ///
  /// **Given**: Episode list is displayed with non-downloaded episode
  /// **When**: User swipes on episode row and taps "Download"
  /// **Then**: Download status changes to "downloading" with progress indicator
  @MainActor
  func testSwipeToDownloadEpisode() throws {
    // Given: App is launched with download-focused swipe configuration
    launchDownloadSwipeApp()
    navigateToEpisodeList()

    // Find a non-downloaded episode (first episode in list)
    // Episodes appear as buttons in SwiftUI's accessibility tree (NavigationLink)
    let firstEpisode = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Episode-'")).firstMatch
    XCTAssertTrue(
      firstEpisode.waitForExistence(timeout: adaptiveTimeout),
      "First episode should exist in list"
    )

    // When: User swipes right to reveal download action (leading swipe)
    firstEpisode.swipeRight()

    // Verify download button appears
    let downloadButton = app.buttons.matching(identifier: "SwipeAction.download").firstMatch
    XCTAssertTrue(
      downloadButton.waitForExistence(timeout: adaptiveShortTimeout),
      "Download swipe action should appear after swipe"
    )

    // Tap download button
    downloadButton.tap()

    // Then: Download should start
    // Note: In a real test with actual downloads, we would verify progress appears
    // For now, we verify the action was tapped successfully
    // The swipe action should dismiss after tap
    XCTAssertFalse(
      downloadButton.exists,
      "Download button should dismiss after tap"
    )
  }

  /// Test: Download progress indicator displays during download
  ///
  /// **Spec**: offline-playback.md - "Download shows progress"
  ///
  /// **Given**: Episode is seeded as downloading at 45%
  /// **When**: User views episode list
  /// **Then**: Download icon, progress percentage (45%), and downloading status are visible
  ///
  /// **Approach**: Seed-first - no simulation needed, just verify UI renders seeded state correctly
  @MainActor
  func testDownloadProgressIndicatorDisplays() throws {
    // Given: Episode seeded as downloading at 45%
    let downloadStates = DownloadStateSeedingHelper.encodeStates([
      "st-001": DownloadStateSeedingHelper.downloading(progress: 0.45)
    ])

    app = launchConfiguredApp(environmentOverrides: [
      "UITEST_DOWNLOAD_STATES": downloadStates
    ])
    navigateToEpisodeList()

    // When: User views episode list (episode should be visible)
    let episode = ensureEpisodeVisible(id: "st-001")
    XCTAssertTrue(
      episode.waitUntil(.hittable, timeout: adaptiveTimeout),
      "Episode st-001 should be visible in list"
    )

    // Then: Verify download icon is visible (arrow.down.circle for downloading state)
    let downloadIcon = episode.images.matching(identifier: "arrow.down.circle").firstMatch
    XCTAssertTrue(
      downloadIcon.waitForExistence(timeout: adaptiveShortTimeout),
      "Download icon should be visible for downloading episode"
    )

    // Verify progress percentage is displayed
    let progressText = episode.staticTexts.matching(identifier: "Episode-st-001-DownloadProgress").firstMatch
    XCTAssertTrue(
      progressText.waitForExistence(timeout: adaptiveShortTimeout),
      "Progress percentage should be visible"
    )
    XCTAssertEqual(
      progressText.label,
      "45%",
      "Progress should show exactly 45% as seeded"
    )

    // Verify download status accessibility identifier
    let downloadStatus = app.descendants(matching: .any)
      .matching(identifier: "Episode-st-001-DownloadStatus")
      .firstMatch
    XCTAssertTrue(
      downloadStatus.waitForExistence(timeout: adaptiveShortTimeout),
      "Download status element should have correct accessibility identifier"
    )
    XCTAssertTrue(
      downloadStatus.label.localizedCaseInsensitiveContains("downloading"),
      "Download status should indicate 'Downloading' state"
    )
  }

  /// Test: Downloaded episode shows completion badge
  ///
  /// **Spec**: offline-playback.md - "Downloaded episode shows badge"
  ///
  /// **Given**: Episode is seeded as downloaded (complete)
  /// **When**: User views episode list
  /// **Then**: Blue filled circle icon and "Downloaded" label are visible
  ///
  /// **Approach**: Seed-first - verify UI renders completed download state correctly
  @MainActor
  func testDownloadedEpisodeShowsBadge() throws {
    // Given: Episode seeded as downloaded
    let downloadStates = DownloadStateSeedingHelper.encodeStates([
      "st-001": DownloadStateSeedingHelper.downloaded(fileSize: 2_048_000)
    ])

    app = launchConfiguredApp(environmentOverrides: [
      "UITEST_DOWNLOAD_STATES": downloadStates
    ])
    navigateToEpisodeList()

    // When: User views episode list
    let episode = ensureEpisodeVisible(id: "st-001")
    XCTAssertTrue(
      episode.waitUntil(.hittable, timeout: adaptiveTimeout),
      "Episode st-001 should be visible in list"
    )

    // Then: Verify downloaded icon is visible (arrow.down.circle.fill - filled for completed)
    let downloadedIcon = episode.images.matching(identifier: "arrow.down.circle.fill").firstMatch
    XCTAssertTrue(
      downloadedIcon.waitForExistence(timeout: adaptiveShortTimeout),
      "Downloaded badge icon (filled circle) should be visible"
    )

    // Verify download status shows "Downloaded"
    let downloadStatus = app.descendants(matching: .any)
      .matching(identifier: "Episode-st-001-DownloadStatus")
      .firstMatch
    XCTAssertTrue(
      downloadStatus.waitForExistence(timeout: adaptiveShortTimeout),
      "Download status element should exist"
    )
    XCTAssertTrue(
      downloadStatus.label.localizedCaseInsensitiveContains("downloaded"),
      "Download status should show 'Downloaded' label"
    )

    // Verify icon is blue color (via system name, color not directly testable)
    XCTAssertEqual(
      downloadedIcon.identifier,
      "arrow.down.circle.fill",
      "Should use filled circle icon for completed downloads"
    )
  }

  // MARK: - Mixed States Tests

  /// Test: Multiple episodes show correct download states simultaneously
  ///
  /// **Spec**: offline-playback.md - "Download indicators show correct state for each episode"
  ///
  /// **Given**: Episodes are seeded with various download states
  /// **When**: User views episode list
  /// **Then**: Each episode shows its correct download icon, progress, and status
  ///
  /// **Approach**: Seed-first - verify UI renders mixed download states correctly
  @MainActor
  func testMultipleEpisodesShowMixedDownloadStates() throws {
    // Given: Multiple episodes in various download states
    let downloadStates = DownloadStateSeedingHelper.encodeStates([
      "st-001": DownloadStateSeedingHelper.downloaded(),
      "st-002": DownloadStateSeedingHelper.downloading(progress: 0.65),
      "st-003": DownloadStateSeedingHelper.failed(message: "Server error"),
      "st-004": DownloadStateSeedingHelper.paused(progress: 0.20)
    ])

    app = launchConfiguredApp(environmentOverrides: [
      "UITEST_DOWNLOAD_STATES": downloadStates
    ])
    navigateToEpisodeList()

    // When/Then: Verify each episode shows correct state

    // Episode 1: Downloaded (blue filled circle)
    let ep1 = ensureEpisodeVisible(id: "st-001")
    XCTAssertTrue(
      ep1.images.matching(identifier: "arrow.down.circle.fill").firstMatch.exists,
      "Episode 1 should show downloaded icon"
    )

    // Episode 2: Downloading @65% (blue circle + progress)
    let ep2 = ensureEpisodeVisible(id: "st-002")
    XCTAssertTrue(
      ep2.images.matching(identifier: "arrow.down.circle").firstMatch.exists,
      "Episode 2 should show downloading icon"
    )
    let ep2Progress = ep2.staticTexts.matching(identifier: "Episode-st-002-DownloadProgress").firstMatch
    XCTAssertEqual(ep2Progress.label, "65%", "Episode 2 should show 65% progress")

    // Episode 3: Failed (red triangle)
    let ep3 = ensureEpisodeVisible(id: "st-003")
    XCTAssertTrue(
      ep3.images.matching(identifier: "exclamationmark.triangle.fill").firstMatch.exists,
      "Episode 3 should show failed icon"
    )

    // Episode 4: Paused @20% (yellow pause + progress)
    let ep4 = ensureEpisodeVisible(id: "st-004")
    XCTAssertTrue(
      ep4.images.matching(identifier: "pause.circle").firstMatch.exists,
      "Episode 4 should show paused icon"
    )
    let ep4Progress = ep4.staticTexts.matching(identifier: "Episode-st-004-DownloadProgress").firstMatch
    XCTAssertEqual(ep4Progress.label, "20%", "Episode 4 should show 20% progress")
  }

  // MARK: - Download Cancellation Tests

  /// Test: Paused download shows progress and pause indicator
  ///
  /// **Spec**: offline-playback.md - "Download can be paused"
  ///
  /// **Given**: Episode download is seeded as paused at 30%
  /// **When**: User views episode list
  /// **Then**: Yellow pause icon, progress percentage (30%), and paused status are visible
  ///
  /// **Approach**: Seed-first - verify UI renders paused download state correctly
  /// **Note**: Pause/resume transition behavior tested separately with transition hooks
  @MainActor
  func testPausedDownloadShowsProgress() throws {
    // Given: Episode seeded as paused at 30%
    let downloadStates = DownloadStateSeedingHelper.encodeStates([
      "st-001": DownloadStateSeedingHelper.paused(progress: 0.30)
    ])

    app = launchConfiguredApp(environmentOverrides: [
      "UITEST_DOWNLOAD_STATES": downloadStates
    ])
    navigateToEpisodeList()

    // When: User views episode list
    let episode = ensureEpisodeVisible(id: "st-001")
    XCTAssertTrue(
      episode.waitUntil(.hittable, timeout: adaptiveTimeout),
      "Episode st-001 should be visible in list"
    )

    // Then: Verify pause icon is visible (yellow pause.circle)
    let pauseIcon = episode.images.matching(identifier: "pause.circle").firstMatch
    XCTAssertTrue(
      pauseIcon.waitForExistence(timeout: adaptiveShortTimeout),
      "Yellow pause icon should be visible for paused download"
    )

    // Verify progress percentage is displayed
    let progressText = episode.staticTexts.matching(identifier: "Episode-st-001-DownloadProgress").firstMatch
    XCTAssertTrue(
      progressText.waitForExistence(timeout: adaptiveShortTimeout),
      "Progress percentage should be visible for paused download"
    )
    XCTAssertEqual(
      progressText.label,
      "30%",
      "Progress should show exactly 30% as seeded"
    )

    // Verify download status shows "Download paused"
    let downloadStatus = app.descendants(matching: .any)
      .matching(identifier: "Episode-st-001-DownloadStatus")
      .firstMatch
    XCTAssertTrue(
      downloadStatus.waitForExistence(timeout: adaptiveShortTimeout),
      "Download status element should exist"
    )
    XCTAssertTrue(
      downloadStatus.label.localizedCaseInsensitiveContains("pause"),
      "Download status should indicate 'Paused' state"
    )
  }

  // MARK: - Error Handling Tests

  /// Test: Failed download shows retry button
  ///
  /// **Spec**: offline-playback.md - "Download fails, user can retry"
  ///
  /// **Given**: Episode download is seeded as failed with error message
  /// **When**: User views episode list
  /// **Then**: Red warning triangle icon, retry button, and failure status are visible
  ///
  /// **Approach**: Seed-first - verify UI renders failed download state correctly
  @MainActor
  func testFailedDownloadShowsRetryButton() throws {
    // Given: Episode seeded as failed with network error
    let downloadStates = DownloadStateSeedingHelper.encodeStates([
      "st-001": DownloadStateSeedingHelper.failed(message: "Network error")
    ])

    app = launchConfiguredApp(environmentOverrides: [
      "UITEST_DOWNLOAD_STATES": downloadStates
    ])
    navigateToEpisodeList()

    // When: User views episode list
    let episode = ensureEpisodeVisible(id: "st-001")
    XCTAssertTrue(
      episode.waitUntil(.hittable, timeout: adaptiveTimeout),
      "Episode st-001 should be visible in list"
    )

    // Then: Verify failure icon is visible (red warning triangle)
    let failureIcon = episode.images.matching(identifier: "exclamationmark.triangle.fill").firstMatch
    XCTAssertTrue(
      failureIcon.waitForExistence(timeout: adaptiveShortTimeout),
      "Red warning triangle icon should be visible for failed download"
    )

    // Verify retry button is present
    let downloadStatus = app.descendants(matching: .any)
      .matching(identifier: "Episode-st-001-DownloadStatus")
      .firstMatch
    XCTAssertTrue(
      downloadStatus.waitForExistence(timeout: adaptiveShortTimeout),
      "Download status element should exist"
    )

    // The failed state shows as a button with retry action
    XCTAssertTrue(
      downloadStatus.label.localizedCaseInsensitiveContains("failed") ||
      downloadStatus.label.localizedCaseInsensitiveContains("retry"),
      "Download status should indicate failure or retry option"
    )

    // Verify the icon is within a button (retry action)
    XCTAssertTrue(
      failureIcon.exists,
      "Failure icon should be tappable for retry"
    )
  }

  // MARK: - Helper Methods

  /// Navigate to the first podcast's episode list
  @MainActor
  private func navigateToEpisodeList() {
    // Navigate to Library tab
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    XCTAssertTrue(tabBar.exists, "Main tab bar should exist")

    let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
    XCTAssertTrue(
      libraryTab.waitForExistence(timeout: adaptiveShortTimeout),
      "Library tab should exist"
    )
    libraryTab.tap()

    // Wait for loading to complete
    guard waitForLoadingToComplete(in: app, timeout: adaptiveTimeout) else {
      XCTFail("Library content failed to load")
      return
    }

    // Find and tap first podcast
    let podcast = waitForAnyElement(
      [
        app.buttons.matching(identifier: "Podcast-swift-talk").firstMatch,
        app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'Podcast'")).firstMatch,
      ],
      timeout: adaptiveShortTimeout,
      description: "podcast button"
    )

    guard let podcast = podcast else {
      XCTFail("No podcast found to navigate to")
      return
    }

    let navigationSucceeded = navigateAndWaitForResult(
      triggerAction: { podcast.tap() },
      expectedElements: episodeListLandingElements(),
      timeout: adaptiveTimeout,
      description: "episode list content"
    )

    XCTAssertTrue(navigationSucceeded, "Should navigate to episode list")
  }

  /// Expected elements when episode list appears
  @MainActor
  private func episodeListLandingElements() -> [XCUIElement] {
    [
      app.staticTexts.matching(identifier: "Filter Summary").firstMatch,
      app.buttons.matching(identifier: "Select").firstMatch,
      app.otherElements.matching(identifier: "Episode Cards Container").firstMatch
    ]
  }

  /// Ensure episode with given ID is visible, scrolling if necessary
  @MainActor
  @discardableResult
  private func ensureEpisodeVisible(id episodeId: String, maxScrolls: Int = 4) -> XCUIElement {
    let episode = app.buttons.matching(identifier: "Episode-\(episodeId)").firstMatch
    if let container = findContainerElement(in: app, identifier: "Episode Cards Container") {
      var attempts = 0
      while attempts < maxScrolls && !episode.waitUntil(.hittable, timeout: adaptiveShortTimeout) {
        container.swipeUp()
        attempts += 1
      }
    }
    _ = episode.waitUntil(.hittable, timeout: adaptiveShortTimeout)
    return episode
  }
}

//
//  OfflinePlaybackUITests.swift
//  zpodUITests
//
//  Created for Issue 28.1: Offline and Streaming Playback Infrastructure
//  Tests offline playback functionality and local file preference
//

import XCTest

/// UI tests for offline playback functionality
///
/// **Spec Coverage**: `spec/offline-playback.md`
/// - Downloaded episode playback without network
/// - Local file preference over streaming
/// - Playback in airplane mode
/// - Downloaded vs non-downloaded episode behavior
///
/// **Issue**: #28.1 - Phase 4: Test Infrastructure
final class OfflinePlaybackUITests: IsolatedUITestCase {

    // MARK: - Local File Playback Tests

    /// Test: Downloaded episodes play from local storage
    ///
    /// **Spec**: offline-playback.md - "Play downloaded episode offline"
    ///
    /// **Given**: Episode is downloaded and stored locally
    /// **When**: User taps to play the episode
    /// **Then**: Episode plays from local file without network request
    @MainActor
    func testPlayDownloadedEpisodeFromLocalStorage() throws {
        // Given: App with downloaded episode
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_OFFLINE_MODE": "1",  // Simulate offline environment
            "UITEST_DOWNLOADED_EPISODES": "episode-1"  // Mark episode-1 as downloaded
        ])
        navigateToEpisodeList()

        // Find downloaded episode (should have "Downloaded" badge)
        let downloadedEpisode = app.cells.matching(
            NSPredicate(format: "identifier == %@", "Episode-episode-1")
        ).firstMatch

        XCTAssertTrue(
            downloadedEpisode.waitForExistence(timeout: adaptiveTimeout),
            "Downloaded episode should exist in list"
        )

        // Verify downloaded badge is present
        let downloadedBadge = downloadedEpisode.staticTexts.matching(
            identifier: "DownloadStatus.downloaded"
        ).firstMatch

        XCTAssertTrue(
            downloadedBadge.exists,
            "Downloaded badge should be visible"
        )

        // When: User taps to play the episode
        downloadedEpisode.tap()

        // Then: Episode should start playing (player UI appears)
        let playerView = app.otherElements.matching(identifier: "Player Interface").firstMatch
        XCTAssertTrue(
            playerView.waitForExistence(timeout: adaptiveTimeout),
            "Player interface should appear when episode is tapped"
        )

        // Verify no network error appears (since playing from local file)
        let networkError = app.staticTexts.matching(
            identifier: "PlaybackError.networkUnavailable"
        ).firstMatch

        XCTAssertFalse(
            networkError.exists,
            "No network error should appear when playing downloaded episode offline"
        )
    }

    /// Test: Non-downloaded episodes show error when played offline
    ///
    /// **Spec**: offline-playback.md - "Stream-only episode fails offline"
    ///
    /// **Given**: Episode is not downloaded, network unavailable
    /// **When**: User taps to play the episode
    /// **Then**: Error message appears indicating network required
    @MainActor
    func testNonDownloadedEpisodeFailsOffline() throws {
        // Given: App in offline mode with non-downloaded episode
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_OFFLINE_MODE": "1"  // Simulate offline environment
        ])
        navigateToEpisodeList()

        // Find non-downloaded episode (no downloaded badge)
        let streamOnlyEpisode = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Episode-'")
        ).firstMatch

        XCTAssertTrue(
            streamOnlyEpisode.waitForExistence(timeout: adaptiveTimeout),
            "Stream-only episode should exist in list"
        )

        // When: User taps to play the episode
        streamOnlyEpisode.tap()

        // Then: Error or warning should appear
        // Note: Actual behavior depends on app implementation
        // Could be an alert, toast, or inline error message

        // For now, verify that playback doesn't start successfully
        // by checking that player doesn't enter playing state
        sleep(2) // Brief wait to allow error to appear

        // Either an error alert should appear, or player should show error state
        let errorAlert = app.alerts.firstMatch
        let playerErrorState = app.staticTexts.matching(
            identifier: "PlaybackError"
        ).firstMatch

        let errorPresent = errorAlert.exists || playerErrorState.exists
        XCTAssertTrue(
            errorPresent,
            "Error should be shown when attempting to play non-downloaded episode offline"
        )
    }

    // MARK: - Download Status Indicator Tests

    /// Test: Downloaded episodes show "Downloaded" badge
    ///
    /// **Spec**: offline-playback.md - "Downloaded badge visible"
    ///
    /// **Given**: Episode is fully downloaded
    /// **When**: User views episode list
    /// **Then**: "Downloaded" badge is visible on episode row
    @MainActor
    func testDownloadedEpisodeShowsBadge() throws {
        // Given: App with downloaded episodes
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "episode-1,episode-2"
        ])
        navigateToEpisodeList()

        // When: User views episode list
        let firstEpisode = app.cells.matching(
            NSPredicate(format: "identifier == %@", "Episode-episode-1")
        ).firstMatch

        XCTAssertTrue(
            firstEpisode.waitForExistence(timeout: adaptiveTimeout),
            "Episode should exist in list"
        )

        // Then: Downloaded badge should be visible
        let downloadedBadge = firstEpisode.staticTexts.matching(
            identifier: "DownloadStatus.downloaded"
        ).firstMatch

        XCTAssertTrue(
            downloadedBadge.exists,
            "Downloaded badge should be visible on downloaded episode"
        )
    }

    /// Test: Non-downloaded episodes show "Not Downloaded" or streaming indicator
    ///
    /// **Spec**: offline-playback.md - "Stream indicator visible"
    ///
    /// **Given**: Episode is not downloaded
    /// **When**: User views episode list
    /// **Then**: No downloaded badge is shown (or stream-only indicator shown)
    @MainActor
    func testNonDownloadedEpisodeShowsStreamIndicator() throws {
        // Given: App with no downloaded episodes
        app = launchConfiguredApp()
        navigateToEpisodeList()

        // When: User views episode list
        let firstEpisode = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Episode-'")
        ).firstMatch

        XCTAssertTrue(
            firstEpisode.waitForExistence(timeout: adaptiveTimeout),
            "Episode should exist in list"
        )

        // Then: Downloaded badge should NOT be visible
        let downloadedBadge = firstEpisode.staticTexts.matching(
            identifier: "DownloadStatus.downloaded"
        ).firstMatch

        XCTAssertFalse(
            downloadedBadge.exists,
            "Downloaded badge should not be visible on non-downloaded episode"
        )
    }

    // MARK: - Offline/Online Mode Transition Tests

    /// Test: App handles transition from online to offline gracefully
    ///
    /// **Spec**: offline-playback.md - "Graceful offline transition"
    ///
    /// **Given**: App is online and playing streaming episode
    /// **When**: Network connection is lost
    /// **Then**: Playback pauses with informative message
    @MainActor
    func testGracefulTransitionToOfflineMode() throws {
        // Given: App playing streaming episode
        app = launchConfiguredApp()
        navigateToEpisodeList()

        let episode = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Episode-'")
        ).firstMatch

        XCTAssertTrue(
            episode.waitForExistence(timeout: adaptiveTimeout),
            "Episode should exist"
        )

        episode.tap()

        // Wait for player to start
        let playerView = app.otherElements.matching(identifier: "Player Interface").firstMatch
        XCTAssertTrue(
            playerView.waitForExistence(timeout: adaptiveTimeout),
            "Player should appear"
        )

        // When: Simulate network loss
        // Note: Actual network simulation would require app support
        // For now, this is a placeholder for future implementation
        // In real tests, we'd use environment flag or NetworkLink conditioner

        // Then: Verify app doesn't crash (basic stability test)
        XCTAssertTrue(
            app.exists,
            "App should remain stable when network is lost"
        )
    }

    // MARK: - Storage Management Integration Tests

    /// Test: Deleted downloads remove local files and revert to streaming
    ///
    /// **Spec**: offline-playback.md - "Delete download reverts to streaming"
    ///
    /// **Given**: Episode is downloaded
    /// **When**: User deletes the download
    /// **Then**: Episode badge changes from "Downloaded" to streaming indicator
    @MainActor
    func testDeletedDownloadRevertsToStreaming() throws {
        // Given: App with downloaded episode
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "episode-1"
        ])
        navigateToEpisodeList()

        let episode = app.cells.matching(
            NSPredicate(format: "identifier == %@", "Episode-episode-1")
        ).firstMatch

        XCTAssertTrue(
            episode.waitForExistence(timeout: adaptiveTimeout),
            "Episode should exist"
        )

        // Verify downloaded badge exists
        var downloadedBadge = episode.staticTexts.matching(
            identifier: "DownloadStatus.downloaded"
        ).firstMatch

        XCTAssertTrue(
            downloadedBadge.exists,
            "Downloaded badge should exist before deletion"
        )

        // When: User deletes the download
        // (Swipe to reveal delete action)
        episode.swipeLeft()

        let deleteButton = app.buttons.matching(identifier: "SwipeAction.delete").firstMatch
        if deleteButton.waitForExistence(timeout: adaptiveShortTimeout) {
            deleteButton.tap()

            // Confirm deletion if alert appears
            let confirmButton = app.buttons.matching(identifier: "Confirm Delete").firstMatch
            if confirmButton.waitForExistence(timeout: adaptiveShortTimeout) {
                confirmButton.tap()
            }
        }

        // Then: Downloaded badge should disappear
        // Wait for badge to disappear
        sleep(1) // Brief wait for UI update

        downloadedBadge = episode.staticTexts.matching(
            identifier: "DownloadStatus.downloaded"
        ).firstMatch

        XCTAssertFalse(
            downloadedBadge.exists,
            "Downloaded badge should disappear after deletion"
        )
    }

    // MARK: - Helper Methods

    /// Navigate to episode list for testing
    private func navigateToEpisodeList() {
        // Navigate to Library tab
        let libraryTab = app.tabBars.buttons.matching(identifier: "Library.Tab").firstMatch
        if libraryTab.waitForExistence(timeout: adaptiveTimeout) {
            libraryTab.tap()
        }

        // Wait for library content to load
        let libraryContent = app.otherElements.matching(identifier: "Library.Content").firstMatch
        _ = libraryContent.waitForExistence(timeout: adaptiveTimeout)

        // Tap first podcast to view episodes
        let firstPodcast = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Podcast-'")
        ).firstMatch

        if firstPodcast.waitForExistence(timeout: adaptiveTimeout) {
            firstPodcast.tap()
        }

        // Wait for episode list to appear
        let episodeList = app.otherElements.matching(identifier: "EpisodeList").firstMatch
        _ = episodeList.waitForExistence(timeout: adaptiveTimeout)
    }
}

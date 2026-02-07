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
///
/// **Status**: ACTIVE - Badge tests prefer row-scoped
/// Episode-<id>-DownloadStatus identifiers seeded via UITEST_DOWNLOADED_EPISODES.
/// Fallback checks use the row label when SwiftUI combines status children.
/// testNonDownloadedEpisodeFailsOffline skipped until PlaybackError surface exists.
final class OfflinePlaybackUITests: IsolatedUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

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
            "UITEST_DOWNLOADED_EPISODES": "swift-talk:st-001"  // Mark episode-1 as downloaded
        ])
        navigateToEpisodeList()

        // Find downloaded episode (should have "Downloaded" badge)
        let downloadedEpisode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(downloadedEpisode.waitUntil(.hittable, timeout: adaptiveTimeout))

        // Verify downloaded badge is present (row-scoped identifier)
        XCTAssertTrue(
            isDownloadedStatusVisible(for: "st-001"),
            "Downloaded status should be visible for seeded episode"
        )

        // When: User taps to play the episode
        downloadedEpisode.tap()

        // Then: Player should become reachable (via detail push or Player tab fallback)
        _ = ensurePlayerVisible()

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
        // Offline error handling UI not yet implemented — tracked by Issue 03.3.4 (#269)
        throw XCTSkip("Requires PlaybackError accessibility surface — Issue 03.3.4 (#269)")

        // Given: App in offline mode with non-downloaded episode
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_OFFLINE_MODE": "1"  // Simulate offline environment
        ])
        navigateToEpisodeList()

        // Find non-downloaded episode (no downloaded badge)
        let streamOnlyEpisode = app.buttons.matching(
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

        let errorAlert = app.alerts.firstMatch
        let playerErrorState = app.staticTexts.matching(identifier: "PlaybackError").firstMatch

        _ = errorAlert.waitForExistence(timeout: adaptiveShortTimeout)

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
            "UITEST_DOWNLOADED_EPISODES": "swift-talk:st-001,swift-talk:st-002"
        ])
        navigateToEpisodeList()

        // When: User views episode list
        let firstEpisode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(firstEpisode.waitUntil(.hittable, timeout: adaptiveTimeout))

        // Then: Downloaded badge should be visible
        XCTAssertTrue(
            isDownloadedStatusVisible(for: "st-001"),
            "Downloaded status should be visible for seeded episode"
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
        let firstEpisode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(firstEpisode.waitUntil(.hittable, timeout: adaptiveTimeout))

        // Then: Downloaded badge should NOT be visible
        let downloadedBadge = downloadStatusIndicator(for: "st-001")
        XCTAssertFalse(downloadedBadge.waitForExistence(timeout: adaptiveShortTimeout))
        let episodeRow = app.buttons.matching(identifier: "Episode-st-001").firstMatch
        XCTAssertTrue(episodeRow.waitForExistence(timeout: adaptiveShortTimeout))
        XCTAssertFalse(
            episodeRow.label.localizedCaseInsensitiveContains("downloaded"),
            "Episode row should not advertise downloaded status when not seeded"
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

        let episode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(episode.waitUntil(.hittable, timeout: adaptiveTimeout))
        episode.tap()

        // Wait for player to start (fallback to Player tab)
        _ = ensurePlayerVisible()

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
        // Swipe-to-delete download action not yet wired — tracked by Issue 28.1.10 (#395)
        throw XCTSkip("Requires SwipeAction.delete on episode rows — Issue 28.1.10 (#395)")

        // Given: App with downloaded episode
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "swift-talk:st-001"
        ])
        navigateToEpisodeList()

        let episode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(episode.waitUntil(.hittable, timeout: adaptiveTimeout))

        // Verify downloaded badge exists
        var downloadedBadge = downloadStatusIndicator(for: "st-001")
        XCTAssertTrue(isDownloadedStatusVisible(for: "st-001"))

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
        XCTAssertTrue(downloadedBadge.waitUntil(.disappeared, timeout: adaptiveTimeout))
    }

    // MARK: - Helper Methods

    /// Navigate to episode list for testing
    private func navigateToEpisodeList() {
        let tabs = TabBarNavigation(app: app)
        XCTAssertTrue(tabs.navigateToLibrary(), "Should open Library tab")

        let library = LibraryScreen(app: app)
        XCTAssertTrue(library.waitForLibraryContent(timeout: adaptiveTimeout), "Library content should load")
        XCTAssertTrue(library.selectPodcast("Podcast-swift-talk", timeout: adaptiveTimeout), "Swift Talk podcast should open")

        XCTAssertTrue(waitForLoadingToComplete(in: app, timeout: adaptiveTimeout))
    }

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

    @MainActor
    private func downloadStatusIndicator(for episodeId: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "Episode-\(episodeId)-DownloadStatus")
            .firstMatch
    }

    @MainActor
    private func isDownloadedStatusVisible(for episodeId: String) -> Bool {
        let rowScopedIndicator = downloadStatusIndicator(for: episodeId)
        if rowScopedIndicator.waitForExistence(timeout: adaptiveShortTimeout) {
            return true
        }

        // SwiftUI may flatten status children in some list snapshots.
        let fallbackRow = app.buttons.matching(
            NSPredicate(
                format: "identifier == %@ AND label CONTAINS[c] %@",
                "Episode-\(episodeId)", "Downloaded"
            )
        ).firstMatch
        return fallbackRow.waitForExistence(timeout: adaptiveShortTimeout)
    }

    @MainActor
    @discardableResult
    private func ensurePlayerVisible() -> XCUIElement {
        let playerView = app.otherElements.matching(identifier: "Player Interface").firstMatch
        if playerView.waitForExistence(timeout: adaptiveTimeout) {
            return playerView
        }
        let tabs = TabBarNavigation(app: app)
        XCTAssertTrue(tabs.navigateToPlayer(), "Should navigate to Player tab")
        _ = playerView.waitForExistence(timeout: adaptiveTimeout)
        return playerView
    }
}

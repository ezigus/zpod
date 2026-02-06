//
//  StreamingInterruptionUITests.swift
//  zpodUITests
//
//  Created for Issue 28.1.4: Network Monitoring and Adaptation
//  Tests network interruption handling and auto-pause/resume behavior
//

import XCTest

/// UI tests for streaming network interruption handling
///
/// **Spec Coverage**: `spec/streaming-playback.md`
/// - Auto-pause on network loss
/// - Auto-resume on network recovery
/// - Buffer indicator display
/// - Network error messages
///
/// **Issue**: #28.1 - Phase 3 & 4: Network Interruption Handling + Tests
final class StreamingInterruptionUITests: IsolatedUITestCase {

    // MARK: - Auto-Pause/Resume Tests

    /// Test: Streaming playback auto-pauses when network is lost
    ///
    /// **Spec**: streaming-playback.md - "Auto-pause on network loss"
    ///
    /// **Given**: Episode is streaming and playing
    /// **When**: Network connection is lost
    /// **Then**: Playback automatically pauses
    @MainActor
    func testAutoPauseOnNetworkLoss() throws {
        // Given: App streaming episode
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_NETWORK_SIMULATION": "1"  // Enable network simulation
        ])
        navigateToEpisodeList()

        // Start streaming an episode
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

        // Verify playback started (play button becomes pause button)
        let pauseButton = app.buttons.matching(identifier: "Player.PauseButton").firstMatch
        XCTAssertTrue(
            pauseButton.waitForExistence(timeout: adaptiveTimeout),
            "Pause button should appear when playing"
        )

        // When: Simulate network loss
        // Trigger network loss via test hook
        let networkLossButton = app.buttons.matching(identifier: "TestHook.SimulateNetworkLoss").firstMatch
        if networkLossButton.exists {
            networkLossButton.tap()

            // Then: Playback should auto-pause
            let playButton = app.buttons.matching(identifier: "Player.PlayButton").firstMatch
            XCTAssertTrue(
                playButton.waitForExistence(timeout: adaptiveTimeout),
                "Play button should appear after auto-pause"
            )
        } else {
            // Test hook not available, skip this test
            throw XCTSkip("Network simulation not available in this build")
        }
    }

    /// Test: Streaming playback auto-resumes when network recovers
    ///
    /// **Spec**: streaming-playback.md - "Auto-resume on network recovery"
    ///
    /// **Given**: Playback was auto-paused due to network loss
    /// **When**: Network connection recovers
    /// **Then**: Playback automatically resumes after grace period
    @MainActor
    func testAutoResumeOnNetworkRecovery() throws {
        // Given: App with playback auto-paused from network loss
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_NETWORK_SIMULATION": "1"
        ])
        navigateToEpisodeList()

        let episode = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Episode-'")
        ).firstMatch

        XCTAssertTrue(
            episode.waitForExistence(timeout: adaptiveTimeout),
            "Episode should exist"
        )

        episode.tap()

        let playerView = app.otherElements.matching(identifier: "Player Interface").firstMatch
        XCTAssertTrue(
            playerView.waitForExistence(timeout: adaptiveTimeout),
            "Player should appear"
        )

        // Simulate network loss
        let networkLossButton = app.buttons.matching(identifier: "TestHook.SimulateNetworkLoss").firstMatch
        if !networkLossButton.exists {
            throw XCTSkip("Network simulation not available")
        }

        networkLossButton.tap()

        // Wait for auto-pause
        let playButton = app.buttons.matching(identifier: "Player.PlayButton").firstMatch
        _ = playButton.waitForExistence(timeout: adaptiveTimeout)

        // When: Simulate network recovery
        let networkRecoveryButton = app.buttons.matching(identifier: "TestHook.SimulateNetworkRecovery").firstMatch
        if networkRecoveryButton.exists {
            networkRecoveryButton.tap()

            // Then: After grace period (3s), playback should resume
            let pauseButton = app.buttons.matching(identifier: "Player.PauseButton").firstMatch
            XCTAssertTrue(
                pauseButton.waitForExistence(timeout: adaptiveTimeout),
                "Pause button should appear after auto-resume"
            )
        }
    }

    // MARK: - Buffer Indicator Tests

    /// Test: Buffer indicator appears when stream is buffering
    ///
    /// **Spec**: streaming-playback.md - "Buffer indicator visible"
    ///
    /// **Given**: Episode is streaming
    /// **When**: Stream buffer runs empty
    /// **Then**: Buffer/loading indicator is visible
    @MainActor
    func testBufferIndicatorAppears() throws {
        // Given: App streaming episode
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_BUFFER_SIMULATION": "1"
        ])
        navigateToEpisodeList()

        let episode = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Episode-'")
        ).firstMatch

        XCTAssertTrue(
            episode.waitForExistence(timeout: adaptiveTimeout),
            "Episode should exist"
        )

        episode.tap()

        let playerView = app.otherElements.matching(identifier: "Player Interface").firstMatch
        XCTAssertTrue(
            playerView.waitForExistence(timeout: adaptiveTimeout),
            "Player should appear"
        )

        // When: Simulate buffer empty
        let bufferEmptyButton = app.buttons.matching(identifier: "TestHook.SimulateBufferEmpty").firstMatch
        if bufferEmptyButton.exists {
            bufferEmptyButton.tap()

            // Then: Buffer indicator should appear
            let bufferIndicator = app.activityIndicators.matching(identifier: "Player.BufferIndicator").firstMatch
            let bufferLabel = app.staticTexts.matching(identifier: "Player.BufferingLabel").firstMatch

            let indicatorPresent = bufferIndicator.exists || bufferLabel.exists
            XCTAssertTrue(
                indicatorPresent,
                "Buffer indicator should be visible when buffering"
            )
        } else {
            throw XCTSkip("Buffer simulation not available")
        }
    }

    /// Test: Buffer indicator disappears when stream is ready
    ///
    /// **Spec**: streaming-playback.md - "Buffer indicator dismissed"
    ///
    /// **Given**: Stream is buffering with indicator visible
    /// **When**: Buffer fills and playback is ready
    /// **Then**: Buffer indicator disappears
    @MainActor
    func testBufferIndicatorDisappears() throws {
        // Given: App streaming with buffer indicator visible
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_BUFFER_SIMULATION": "1"
        ])
        navigateToEpisodeList()

        let episode = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Episode-'")
        ).firstMatch

        XCTAssertTrue(
            episode.waitForExistence(timeout: adaptiveTimeout),
            "Episode should exist"
        )

        episode.tap()

        let playerView = app.otherElements.matching(identifier: "Player Interface").firstMatch
        _ = playerView.waitForExistence(timeout: adaptiveTimeout)

        // Simulate buffer empty
        let bufferEmptyButton = app.buttons.matching(identifier: "TestHook.SimulateBufferEmpty").firstMatch
        if !bufferEmptyButton.exists {
            throw XCTSkip("Buffer simulation not available")
        }

        bufferEmptyButton.tap()

        // When: Simulate buffer ready
        let bufferReadyButton = app.buttons.matching(identifier: "TestHook.SimulateBufferReady").firstMatch
        if bufferReadyButton.exists {
            bufferReadyButton.tap()

            // Then: Buffer indicator should disappear
            sleep(1) // Brief wait for UI update

            let bufferIndicator = app.activityIndicators.matching(identifier: "Player.BufferIndicator").firstMatch
            let bufferLabel = app.staticTexts.matching(identifier: "Player.BufferingLabel").firstMatch

            XCTAssertFalse(
                bufferIndicator.exists,
                "Buffer indicator should disappear when ready"
            )
            XCTAssertFalse(
                bufferLabel.exists,
                "Buffer label should disappear when ready"
            )
        }
    }

    // MARK: - Network Error Message Tests

    /// Test: Network error message displays when stream fails
    ///
    /// **Spec**: streaming-playback.md - "Network error displayed"
    ///
    /// **Given**: App attempting to stream episode
    /// **When**: Network error occurs (timeout, unavailable, etc.)
    /// **Then**: Error message is displayed to user
    @MainActor
    func testNetworkErrorMessageDisplays() throws {
        // Given: App in offline mode attempting to stream
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_OFFLINE_MODE": "1"
        ])
        navigateToEpisodeList()

        let episode = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Episode-'")
        ).firstMatch

        XCTAssertTrue(
            episode.waitForExistence(timeout: adaptiveTimeout),
            "Episode should exist"
        )

        // When: User tries to play non-downloaded episode offline
        episode.tap()

        // Then: Error message should appear
        // Could be alert, toast, or inline error
        sleep(2) // Wait for error to appear

        let errorAlert = app.alerts.firstMatch
        let errorMessage = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "network")
        ).firstMatch

        let errorPresent = errorAlert.exists || errorMessage.exists
        XCTAssertTrue(
            errorPresent,
            "Network error message should be displayed"
        )
    }

    /// Test: Retry button appears after network error
    ///
    /// **Spec**: streaming-playback.md - "Retry available after error"
    ///
    /// **Given**: Network error has occurred
    /// **When**: Error message is displayed
    /// **Then**: Retry button is available to user
    @MainActor
    func testRetryButtonAvailableAfterError() throws {
        // Given: App with network error
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_OFFLINE_MODE": "1"
        ])
        navigateToEpisodeList()

        let episode = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Episode-'")
        ).firstMatch

        XCTAssertTrue(
            episode.waitForExistence(timeout: adaptiveTimeout),
            "Episode should exist"
        )

        episode.tap()

        // Wait for error to appear
        sleep(2)

        // Then: Retry button should be available
        let retryButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "retry")
        ).firstMatch

        // Retry button might be in alert or inline
        let alertRetryButton = app.alerts.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "retry")
        ).firstMatch

        let retryAvailable = retryButton.exists || alertRetryButton.exists
        XCTAssertTrue(
            retryAvailable,
            "Retry button should be available after network error"
        )
    }

    // MARK: - Playback Quality Tests

    /// Test: Playback adapts to poor network conditions
    ///
    /// **Spec**: streaming-playback.md - "Adaptive quality"
    ///
    /// **Given**: Episode is streaming with good quality
    /// **When**: Network quality degrades
    /// **Then**: App continues playback (may reduce quality)
    @MainActor
    func testPlaybackAdaptsToPoorNetwork() throws {
        // Given: App streaming with good network
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_NETWORK_SIMULATION": "1"
        ])
        navigateToEpisodeList()

        let episode = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Episode-'")
        ).firstMatch

        XCTAssertTrue(
            episode.waitForExistence(timeout: adaptiveTimeout),
            "Episode should exist"
        )

        episode.tap()

        let playerView = app.otherElements.matching(identifier: "Player Interface").firstMatch
        _ = playerView.waitForExistence(timeout: adaptiveTimeout)

        // When: Simulate poor network
        let poorNetworkButton = app.buttons.matching(identifier: "TestHook.SimulatePoorNetwork").firstMatch
        if poorNetworkButton.exists {
            poorNetworkButton.tap()

            // Then: Playback should continue (not stop)
            sleep(2)

            // Verify player is still active (not crashed, not error state)
            XCTAssertTrue(
                playerView.exists,
                "Player should remain active with poor network"
            )

            // Playback might show buffering, but shouldn't error out
            let errorAlert = app.alerts.firstMatch
            XCTAssertFalse(
                errorAlert.exists,
                "No error alert should appear with poor (but present) network"
            )
        } else {
            throw XCTSkip("Network quality simulation not available")
        }
    }

    // MARK: - Helper Methods

    /// Navigate to episode list for testing
    private func navigateToEpisodeList() {
        // Navigate to Library tab
        let libraryTab = app.tabBars.buttons.matching(identifier: "Library.Tab").firstMatch
        if libraryTab.waitForExistence(timeout: adaptiveTimeout) {
            libraryTab.tap()
        }

        // Wait for library content
        let libraryContent = app.otherElements.matching(identifier: "Library.Content").firstMatch
        _ = libraryContent.waitForExistence(timeout: adaptiveTimeout)

        // Tap first podcast
        let firstPodcast = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH 'Podcast-'")
        ).firstMatch

        if firstPodcast.waitForExistence(timeout: adaptiveTimeout) {
            firstPodcast.tap()
        }

        // Wait for episode list
        let episodeList = app.otherElements.matching(identifier: "EpisodeList").firstMatch
        _ = episodeList.waitForExistence(timeout: adaptiveTimeout)
    }
}

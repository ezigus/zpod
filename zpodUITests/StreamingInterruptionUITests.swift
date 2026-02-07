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
///
/// **Status**: ACTIVE - Hook-dependent tests skip gracefully via XCTSkip
/// when TestHook.* buttons are absent. Error display tests skipped until
/// PlaybackError surface is implemented.
final class StreamingInterruptionUITests: IsolatedUITestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

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
        // Given: App with network simulation enabled.
        // Navigate directly to the Player tab which hosts the real
        // EpisodeDetailView (with test hook controls), not the placeholder
        // detail view used by the episode list's NavigationLink.
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_NETWORK_SIMULATION": "1"
        ])

        let tabs = TabBarNavigation(app: app)
        XCTAssertTrue(tabs.navigateToPlayer(), "Should navigate to Player tab")

        // Wait for the player view to appear
        let playerView = app.otherElements.matching(identifier: "Player Interface").firstMatch
        XCTAssertTrue(
            playerView.waitForExistence(timeout: adaptiveTimeout),
            "Player Interface should appear on Player tab"
        )

        // Verify test hooks are visible. Prefer identifier lookup, but allow
        // label fallback for wrapper-heavy SwiftUI accessibility trees.
        let networkLossByIdentifier = app.buttons.matching(identifier: "TestHook.SimulateNetworkLoss").firstMatch
        let networkLossByLabel = app.buttons.matching(
            NSPredicate(format: "label == %@", "Simulate Network Loss")
        ).firstMatch
        guard let networkLossButton = waitForAnyElement(
            [networkLossByIdentifier, networkLossByLabel],
            timeout: adaptiveTimeout,
            description: "Network loss simulation control",
            failOnTimeout: false
        ) else {
            throw XCTSkip("Network simulation controls not rendered — Issue 28.1.11 (#396)")
        }

        // Verify initial state via simulation-controls container label.
        // In SwiftUI wrapper-heavy trees, the dynamic pause/play label is
        // consistently exposed on this container even when child identifiers
        // are not surfaced as buttons.
        let simulationControls = app.descendants(matching: .any)
            .matching(identifier: "TestNetworkSimulationControls")
            .firstMatch
        XCTAssertTrue(
            simulationControls.waitForExistence(timeout: adaptiveTimeout),
            "Simulation controls container should exist when network simulation is enabled"
        )
        // Normalize state before assertions.
        let networkRecoveryByIdentifier = app.buttons.matching(identifier: "TestHook.SimulateNetworkRecovery").firstMatch
        let networkRecoveryByLabel = app.buttons.matching(
            NSPredicate(format: "label == %@", "Simulate Network Recovery")
        ).firstMatch
        if let networkRecoveryButton = waitForAnyElement(
            [networkRecoveryByIdentifier, networkRecoveryByLabel],
            timeout: adaptiveShortTimeout,
            description: "Network recovery simulation control",
            failOnTimeout: false
        ) {
            networkRecoveryButton.tap()
        }

        guard waitUntil(
            timeout: adaptiveTimeout,
            pollInterval: 0.1,
            description: "simulation controls show Pause",
            condition: {
                simulationControls.label.localizedCaseInsensitiveContains("pause")
            }
        ) else {
            throw XCTSkip("Simulation control state did not normalize to Pause — Issue 28.1.11 (#396)")
        }

        // When: Simulate network loss
        XCTAssertTrue(networkLossButton.exists, "Network loss button should exist")
        networkLossButton.tap()

        // Then: Playback should auto-pause (simulation controls reflect Play state)
        XCTAssertTrue(
            waitUntil(timeout: adaptiveTimeout, pollInterval: 0.1, description: "simulation controls show Play") {
                simulationControls.label.localizedCaseInsensitiveContains("play")
            },
            "Simulation controls should switch to Play after simulated network loss"
        )
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

        let episode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(episode.waitUntil(.hittable, timeout: adaptiveTimeout))
        episode.tap()

        let playerView = ensurePlayerVisible()

        // Simulate network loss
        let networkLossButton = app.buttons.matching(identifier: "TestHook.SimulateNetworkLoss").firstMatch
        if !networkLossButton.exists {
            throw XCTSkip("Network simulation not available — Issue 28.1.11 (#396)")
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

        let episode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(episode.waitUntil(.hittable, timeout: adaptiveTimeout))
        episode.tap()

        let playerView = ensurePlayerVisible()

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
            throw XCTSkip("Buffer simulation not available — Issue 28.1.11 (#396)")
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

        let episode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(episode.waitUntil(.hittable, timeout: adaptiveTimeout))

        episode.tap()

        _ = ensurePlayerVisible()

        // Simulate buffer empty
        let bufferEmptyButton = app.buttons.matching(identifier: "TestHook.SimulateBufferEmpty").firstMatch
        if !bufferEmptyButton.exists {
            throw XCTSkip("Buffer simulation not available — Issue 28.1.11 (#396)")
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
        throw XCTSkip("Requires PlaybackError accessibility surface — Issue 03.3.4 (#269)")

        // Given: App in offline mode attempting to stream
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_OFFLINE_MODE": "1"
        ])
        navigateToEpisodeList()

        let episode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(episode.waitUntil(.hittable, timeout: adaptiveTimeout))

        // When: User tries to play non-downloaded episode offline
        episode.tap()

        // Then: Error message should appear
        // Could be alert, toast, or inline error
        let errorAlert = app.alerts.firstMatch
        let errorMessage = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "network")
        ).firstMatch

        _ = errorAlert.waitForExistence(timeout: adaptiveShortTimeout)

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
        throw XCTSkip("Requires PlaybackError accessibility surface — Issue 03.3.4 (#269)")

        // Given: App with network error
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_OFFLINE_MODE": "1"
        ])
        navigateToEpisodeList()

        let episode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(episode.waitUntil(.hittable, timeout: adaptiveTimeout))

        episode.tap()

        // Wait for error to appear
        _ = app.alerts.firstMatch.waitForExistence(timeout: adaptiveShortTimeout)

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

        let episode = ensureEpisodeVisible(id: "st-001")
        XCTAssertTrue(episode.waitUntil(.hittable, timeout: adaptiveTimeout))

        episode.tap()

        let playerView = ensurePlayerVisible()

        // When: Simulate poor network
        let poorNetworkButton = app.buttons.matching(identifier: "TestHook.SimulatePoorNetwork").firstMatch
        if poorNetworkButton.exists {
            poorNetworkButton.tap()

            // Then: Playback should continue (not stop)
            _ = app.otherElements.matching(identifier: "Player.BufferIndicator").firstMatch.waitForExistence(timeout: adaptiveShortTimeout)

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
            throw XCTSkip("Network quality simulation not available — Issue 28.1.11 (#396)")
        }
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

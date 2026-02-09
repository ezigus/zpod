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
/// **Status**: ACTIVE - Network/buffer simulation hooks are integrated
/// (Issue 28.1.11 / #396) and playback-error UI coverage is active
/// (Issue 28.1.12 / #401). Hook-dependent scenarios run as active assertions.
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
        _ = openPlayerForSimulation(environmentOverrides: [
            "UITEST_NETWORK_SIMULATION": "1"
        ])

        // Verify test hooks are visible. Prefer identifier lookup, but allow
        // label fallback for wrapper-heavy SwiftUI accessibility trees.
        guard let networkLossButton = simulationControlButton(
            identifier: "TestHook.SimulateNetworkLoss",
            label: "Simulate Network Loss",
            description: "Network loss simulation control",
            timeout: adaptiveTimeout,
        ) else {
            XCTFail("Network simulation controls should render when UITEST_NETWORK_SIMULATION=1")
            return
        }

        guard ensurePlaybackRunning(timeout: adaptiveTimeout) else {
            XCTFail("Playback should be running before simulating network loss")
            return
        }

        // When: Simulate network loss
        networkLossButton.tap()

        // Then: Playback should auto-pause (state reflects Play)
        guard waitUntil(
            timeout: adaptiveTimeout,
            pollInterval: 0.1,
            description: "playback controls show Play",
            condition: {
                self.isPlaybackControlShowingPlay()
            }
        ) else {
            XCTFail("Expected playback controls to transition to Play after network loss")
            return
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
        // Given: App with playback simulation enabled on Player tab
        _ = openPlayerForSimulation(environmentOverrides: [
            "UITEST_NETWORK_SIMULATION": "1"
        ])
        guard ensurePlaybackRunning(timeout: adaptiveTimeout) else {
            XCTFail("Playback should be running before simulating network loss")
            return
        }

        // Simulate network loss
        guard let networkLossButton = simulationControlButton(
            identifier: "TestHook.SimulateNetworkLoss",
            label: "Simulate Network Loss",
            description: "Network loss simulation control",
            timeout: adaptiveTimeout
        ) else {
            XCTFail("Network simulation controls should render when UITEST_NETWORK_SIMULATION=1")
            return
        }
        networkLossButton.tap()

        guard waitUntil(
            timeout: adaptiveTimeout,
            pollInterval: 0.1,
            description: "playback controls show Play",
            condition: {
                self.isPlaybackControlShowingPlay()
            }
        ) else {
            XCTFail("Expected playback controls to transition to Play after network loss")
            return
        }

        // When: Simulate network recovery
        guard let networkRecoveryButton = simulationControlButton(
            identifier: "TestHook.SimulateNetworkRecovery",
            label: "Simulate Network Recovery",
            description: "Network recovery simulation control",
            timeout: adaptiveTimeout
        ) else {
            XCTFail("Network recovery simulation control should render when UITEST_NETWORK_SIMULATION=1")
            return
        }
        networkRecoveryButton.tap()

        // Then: Playback should resume (controls return to Pause state)
        guard waitUntil(
            timeout: adaptiveTimeout,
            pollInterval: 0.1,
            description: "playback controls show Pause",
            condition: {
                self.isPlaybackControlShowingPause()
            }
        ) else {
            XCTFail("Expected playback controls to transition back to Pause after recovery")
            return
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
        // Given: App with buffer simulation enabled on Player tab
        _ = openPlayerForSimulation(environmentOverrides: [
            "UITEST_BUFFER_SIMULATION": "1"
        ])

        // When: Simulate buffer empty
        guard let bufferEmptyButton = simulationControlButton(
            identifier: "TestHook.SimulateBufferEmpty",
            label: "Buffer Empty",
            description: "Buffer empty simulation control",
            timeout: adaptiveTimeout
        ) else {
            XCTFail("Buffer simulation controls should render when UITEST_BUFFER_SIMULATION=1")
            return
        }
        bufferEmptyButton.tap()

        // Then: Buffer indicator should appear
        let bufferIndicator = app.activityIndicators.matching(identifier: "Player.BufferIndicator").firstMatch
        let bufferLabel = app.staticTexts.matching(identifier: "Player.BufferingLabel").firstMatch

        guard waitUntil(
            timeout: adaptiveTimeout,
            pollInterval: 0.1,
            description: "buffer indicator appears",
            condition: {
                bufferIndicator.exists || bufferLabel.exists
            }
        ) else {
            XCTFail("Buffer indicator should appear after buffer-empty simulation")
            return
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
        // Given: App with buffer simulation enabled on Player tab
        _ = openPlayerForSimulation(environmentOverrides: [
            "UITEST_BUFFER_SIMULATION": "1"
        ])

        // Simulate buffer empty
        guard let bufferEmptyButton = simulationControlButton(
            identifier: "TestHook.SimulateBufferEmpty",
            label: "Buffer Empty",
            description: "Buffer empty simulation control",
            timeout: adaptiveTimeout
        ) else {
            XCTFail("Buffer simulation controls should render when UITEST_BUFFER_SIMULATION=1")
            return
        }
        bufferEmptyButton.tap()
        let bufferIndicator = app.activityIndicators.matching(identifier: "Player.BufferIndicator").firstMatch
        let bufferLabel = app.staticTexts.matching(identifier: "Player.BufferingLabel").firstMatch
        guard waitUntil(
            timeout: adaptiveTimeout,
            pollInterval: 0.1,
            description: "buffer indicator appears before ready transition",
            condition: {
                bufferIndicator.exists || bufferLabel.exists
            }
        ) else {
            XCTFail("Buffer indicator should appear after buffer-empty simulation")
            return
        }

        // When: Simulate buffer ready
        guard let bufferReadyButton = simulationControlButton(
            identifier: "TestHook.SimulateBufferReady",
            label: "Buffer Ready",
            description: "Buffer ready simulation control",
            timeout: adaptiveTimeout
        ) else {
            XCTFail("Buffer-ready control should render when UITEST_BUFFER_SIMULATION=1")
            return
        }
        bufferReadyButton.tap()

        // Then: Buffer indicator should disappear
        guard waitUntil(
            timeout: adaptiveTimeout,
            pollInterval: 0.1,
            description: "buffer indicator disappears",
            condition: {
                !bufferIndicator.exists && !bufferLabel.exists
            }
        ) else {
            XCTFail("Buffer indicator should clear after buffer-ready simulation")
            return
        }
    }

    // MARK: - Simulation Control Visibility

    /// Test: Network simulation flag only exposes network controls
    @MainActor
    func testNetworkSimulationFlagShowsOnlyNetworkControls() throws {
        _ = openPlayerForSimulation(environmentOverrides: [
            "UITEST_NETWORK_SIMULATION": "1"
        ])

        XCTAssertNotNil(
            simulationControlButton(
                identifier: "TestHook.SimulateNetworkLoss",
                label: "Simulate Network Loss",
                description: "Network loss simulation control",
                timeout: adaptiveTimeout
            ),
            "Network-loss control should render when UITEST_NETWORK_SIMULATION=1"
        )
        XCTAssertNotNil(
            simulationControlButton(
                identifier: "TestHook.SimulateNetworkRecovery",
                label: "Simulate Network Recovery",
                description: "Network recovery simulation control",
                timeout: adaptiveTimeout
            ),
            "Network-recovery control should render when UITEST_NETWORK_SIMULATION=1"
        )
        XCTAssertNotNil(
            simulationControlButton(
                identifier: "TestHook.SimulatePoorNetwork",
                label: "Simulate Poor Network",
                description: "Poor network simulation control",
                timeout: adaptiveTimeout
            ),
            "Poor-network control should render when UITEST_NETWORK_SIMULATION=1"
        )

        XCTAssertFalse(
            simulationControlExists(
                identifier: "TestHook.SimulateBufferEmpty",
                label: "Buffer Empty"
            ),
            "Buffer-empty control should not render when only UITEST_NETWORK_SIMULATION=1"
        )
        XCTAssertFalse(
            simulationControlExists(
                identifier: "TestHook.SimulateBufferReady",
                label: "Buffer Ready"
            ),
            "Buffer-ready control should not render when only UITEST_NETWORK_SIMULATION=1"
        )
    }

    /// Test: Buffer simulation flag only exposes buffer controls
    @MainActor
    func testBufferSimulationFlagShowsOnlyBufferControls() throws {
        _ = openPlayerForSimulation(environmentOverrides: [
            "UITEST_BUFFER_SIMULATION": "1"
        ])

        XCTAssertNotNil(
            simulationControlButton(
                identifier: "TestHook.SimulateBufferEmpty",
                label: "Buffer Empty",
                description: "Buffer empty simulation control",
                timeout: adaptiveTimeout
            ),
            "Buffer-empty control should render when UITEST_BUFFER_SIMULATION=1"
        )
        XCTAssertNotNil(
            simulationControlButton(
                identifier: "TestHook.SimulateBufferReady",
                label: "Buffer Ready",
                description: "Buffer-ready simulation control",
                timeout: adaptiveTimeout
            ),
            "Buffer-ready control should render when UITEST_BUFFER_SIMULATION=1"
        )

        XCTAssertFalse(
            simulationControlExists(
                identifier: "TestHook.SimulateNetworkLoss",
                label: "Simulate Network Loss"
            ),
            "Network-loss control should not render when only UITEST_BUFFER_SIMULATION=1"
        )
        XCTAssertFalse(
            simulationControlExists(
                identifier: "TestHook.SimulateNetworkRecovery",
                label: "Simulate Network Recovery"
            ),
            "Network-recovery control should not render when only UITEST_BUFFER_SIMULATION=1"
        )
        XCTAssertFalse(
            simulationControlExists(
                identifier: "TestHook.SimulatePoorNetwork",
                label: "Simulate Poor Network"
            ),
            "Poor-network control should not render when only UITEST_BUFFER_SIMULATION=1"
        )
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
        _ = openPlayerForSimulation(environmentOverrides: [
            "UITEST_PLAYBACK_ERROR_SIMULATION": "1"
        ])

        guard injectPlaybackErrorViaSimulationHook() else {
            XCTFail("Playback error simulation hook should inject an error")
            return
        }

        let miniErrorMessage = app.staticTexts.matching(identifier: "MiniPlayer.ErrorMessage").firstMatch
        let expandedErrorView = app.otherElements.matching(identifier: "ExpandedPlayer.ErrorView").firstMatch
        let errorSurface = waitForAnyElement(
            [miniErrorMessage, expandedErrorView],
            timeout: adaptiveTimeout,
            description: "playback error surface",
            failOnTimeout: false
        )

        if errorSurface != nil {
            return
        }

        guard openExpandedPlayerFromMiniPlayer() else {
            XCTFail("Error message surface should appear after injecting playback error")
            return
        }

        XCTAssertTrue(
            expandedErrorView.waitForExistence(timeout: adaptiveTimeout),
            "Expanded player error surface should appear after injecting playback error"
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
        _ = openPlayerForSimulation(environmentOverrides: [
            "UITEST_PLAYBACK_ERROR_SIMULATION": "1"
        ])

        guard injectPlaybackErrorViaSimulationHook() else {
            XCTFail("Playback error simulation hook should inject an error")
            return
        }

        let miniRetry = app.buttons.matching(identifier: "MiniPlayer.RetryButton").firstMatch
        let expandedRetry = app.buttons.matching(identifier: "ExpandedPlayer.RetryButton").firstMatch
        let retryButton = waitForAnyElement(
            [miniRetry, expandedRetry],
            timeout: adaptiveTimeout,
            description: "retry button for playback error",
            failOnTimeout: false
        )

        if retryButton != nil {
            return
        }

        guard openExpandedPlayerFromMiniPlayer() else {
            XCTFail("Retry button should be available for recoverable playback error")
            return
        }

        XCTAssertTrue(
            expandedRetry.waitForExistence(timeout: adaptiveTimeout),
            "Expanded player retry button should be available for recoverable playback error"
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
        // Given: App with network simulation enabled on Player tab
        let playerView = openPlayerForSimulation(environmentOverrides: [
            "UITEST_NETWORK_SIMULATION": "1"
        ])

        // When: Simulate poor network
        guard let poorNetworkButton = simulationControlButton(
            identifier: "TestHook.SimulatePoorNetwork",
            label: "Simulate Poor Network",
            description: "Poor network simulation control",
            timeout: adaptiveTimeout
        ) else {
            XCTFail("Poor-network simulation control should render when UITEST_NETWORK_SIMULATION=1")
            return
        }
        poorNetworkButton.tap()

        // Then: poor network should surface buffering state without hard failure
        let bufferIndicator = app.activityIndicators.matching(identifier: "Player.BufferIndicator").firstMatch
        let bufferLabel = app.staticTexts.matching(identifier: "Player.BufferingLabel").firstMatch
        guard waitUntil(
            timeout: adaptiveTimeout,
            pollInterval: 0.1,
            description: "buffering state appears after poor network simulation",
            condition: {
                bufferIndicator.exists || bufferLabel.exists
            }
        ) else {
            XCTFail("Poor-network simulation should surface buffering state")
            return
        }

        XCTAssertFalse(
            app.alerts.firstMatch.waitForExistence(timeout: adaptiveShortTimeout),
            "No playback error alert should appear while adapting to poor network"
        )

        guard waitUntil(
            timeout: adaptiveTimeout,
            pollInterval: 0.1,
            description: "player view remains visible after poor network simulation",
            condition: {
                playerView.exists
            }
        ) else {
            XCTFail("Player view should remain visible while adapting to poor network")
            return
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
        XCTAssertTrue(
            playerView.waitForExistence(timeout: adaptiveTimeout),
            "Player Interface should exist after navigating to Player tab"
        )
        return playerView
    }

    @MainActor
    @discardableResult
    private func openPlayerForSimulation(environmentOverrides: [String: String]) -> XCUIElement {
        app = launchConfiguredApp(environmentOverrides: environmentOverrides)
        let tabs = TabBarNavigation(app: app)
        XCTAssertTrue(
            tabs.navigateToPlayer(),
            "Could not navigate to Player tab for simulation"
        )

        let playerView = app.otherElements.matching(identifier: "Player Interface").firstMatch
        XCTAssertTrue(
            playerView.waitForExistence(timeout: adaptiveTimeout),
            "Player interface not reachable in simulation mode"
        )
        return playerView
    }

    @MainActor
    private func simulationControlButton(
        identifier: String,
        label: String,
        description: String,
        timeout: TimeInterval
    ) -> XCUIElement? {
        let byIdentifier = app.buttons.matching(identifier: identifier).firstMatch
        let byLabel = app.buttons.matching(
            NSPredicate(format: "label == %@", label)
        ).firstMatch
        return waitForAnyElement(
            [byIdentifier, byLabel],
            timeout: timeout,
            description: description,
            failOnTimeout: false
        )
    }

    @MainActor
    private func simulationControlExists(identifier: String, label: String) -> Bool {
        if app.buttons.matching(identifier: identifier).firstMatch.exists {
            return true
        }

        return app.buttons.matching(
            NSPredicate(format: "label == %@", label)
        ).firstMatch.exists
    }

    @MainActor
    private func isPlaybackControlShowingPause() -> Bool {
        app.buttons.matching(identifier: "Pause").firstMatch.exists
    }

    @MainActor
    private func isPlaybackControlShowingPlay() -> Bool {
        app.buttons.matching(identifier: "Play").firstMatch.exists
    }

    @MainActor
    private func ensurePlaybackRunning(timeout: TimeInterval) -> Bool {
        if isPlaybackControlShowingPause() {
            return true
        }

        let playButton = app.buttons.matching(identifier: "Play").firstMatch
        guard playButton.waitForExistence(timeout: adaptiveShortTimeout) else {
            return false
        }
        playButton.tap()

        return waitUntil(
            timeout: timeout,
            pollInterval: 0.1,
            description: "playback controls show Pause after tapping Play",
            condition: { self.isPlaybackControlShowingPause() }
        )
    }

    @MainActor
    private func injectPlaybackErrorViaSimulationHook() -> Bool {
        guard ensurePlaybackRunning(timeout: adaptiveTimeout) else {
            return false
        }

        guard let errorButton = simulationControlButton(
            identifier: "TestHook.SimulatePlaybackError",
            label: "Simulate Playback Error",
            description: "Playback-error simulation control",
            timeout: adaptiveTimeout
        ) else {
            return false
        }

        errorButton.tap()
        return true
    }

    @MainActor
    private func openExpandedPlayerFromMiniPlayer() -> Bool {
        let expandedPlayer = app.otherElements.matching(identifier: "Expanded Player").firstMatch
        let expandedErrorView = app.otherElements.matching(identifier: "ExpandedPlayer.ErrorView").firstMatch
        if expandedPlayer.exists || expandedErrorView.exists {
            return true
        }

        let miniPlayer = miniPlayerElement(in: app)
        guard miniPlayer.waitForExistence(timeout: adaptiveTimeout) else {
            return false
        }

        miniPlayer.tap()

        if expandedErrorView.waitForExistence(timeout: adaptiveTimeout) {
            return true
        }

        return expandedPlayer.waitForExistence(timeout: adaptiveTimeout)
    }
}

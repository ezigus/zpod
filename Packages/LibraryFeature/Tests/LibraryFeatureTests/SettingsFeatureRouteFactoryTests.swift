import XCTest
import SwiftUI
import CoreModels
@testable import LibraryFeature
@testable import SettingsDomain

@MainActor
final class SettingsFeatureRouteFactoryTests: XCTestCase {
    func testMakeRouteReturnsSwipeRoute() async {
        let service = InMemorySwipeService(initial: .default)
        let controller = SwipeConfigurationController(service: service)

        let route = SettingsFeatureRouteFactory.makeRoute(
            descriptorID: "swipeActions",
            controller: controller
        )

        XCTAssertNotNil(route, "Expected swipe route")
        await route?.loadBaseline()
        XCTAssertEqual(controller.draft, .default)

        let destination = route?.destination()
        XCTAssertNotNil(destination)
    }

    func testMakeRouteReturnsNotificationsRoute() async {
        let initial = NotificationSettings(
            newEpisodeNotificationsEnabled: false,
            downloadCompleteNotificationsEnabled: true,
            playbackNotificationsEnabled: true,
            quietHoursEnabled: false,
            deliverySchedule: .dailyDigest,
            focusModeIntegrationEnabled: true,
            liveActivitiesEnabled: false
        )
        let service = InMemoryNotificationsService(initial: initial)
        let controller = NotificationsConfigurationController(service: service)

        let route = SettingsFeatureRouteFactory.makeRoute(
            descriptorID: "notifications",
            controller: controller
        )

        XCTAssertNotNil(route)
        await route?.loadBaseline()
        XCTAssertEqual(controller.deliverySchedule, .dailyDigest)
        XCTAssertNotNil(route?.destination())
    }

    func testMakeRouteReturnsAppearanceRoute() async {
        let initial = AppearanceSettings(
            theme: .dark,
            preferredTint: .purple,
            typographyScale: 1.2,
            reduceMotionEnabled: true,
            reduceHapticsEnabled: false,
            highContrastEnabled: true
        )
        let service = InMemoryAppearanceService(initial: initial)
        let controller = AppearanceConfigurationController(service: service)

        let route = SettingsFeatureRouteFactory.makeRoute(
            descriptorID: "appearance",
            controller: controller
        )

        XCTAssertNotNil(route)
        await route?.loadBaseline()
        XCTAssertEqual(controller.typographyScale, 1.2, accuracy: 0.001)
        XCTAssertNotNil(route?.destination())
    }

    func testMakeRouteReturnsPlaybackRoute() async {
        let initial = PlaybackSettings(globalPlaybackSpeed: 1.5)
        let service = InMemoryPlaybackService(initial: initial)
        let controller = PlaybackConfigurationController(service: service)

        let route = SettingsFeatureRouteFactory.makeRoute(
            descriptorID: "playbackPreferences",
            controller: controller
        )

        XCTAssertNotNil(route)
        await route?.loadBaseline()
        XCTAssertEqual(controller.currentSettings.globalPlaybackSpeed, 1.5)
        XCTAssertNotNil(route?.destination())
    }

    func testMakeRouteReturnsDownloadRoute() async {
        var initial = DownloadSettings.default
        initial.autoDownloadEnabled = false
        let service = InMemoryDownloadService(initial: initial)
        let controller = DownloadConfigurationController(service: service)

        let route = SettingsFeatureRouteFactory.makeRoute(
            descriptorID: "downloadPolicies",
            controller: controller
        )

        XCTAssertNotNil(route)
        await route?.loadBaseline()
        XCTAssertFalse(controller.autoDownloadEnabled)
        XCTAssertNotNil(route?.destination())
    }

    func testUnknownDescriptorReturnsNil() async {
        let service = InMemorySwipeService(initial: .default)
        let controller = SwipeConfigurationController(service: service)

        let route = SettingsFeatureRouteFactory.makeRoute(
            descriptorID: "unknown",
            controller: controller
        )

        XCTAssertNil(route)
    }
}

// MARK: - Test Doubles

actor InMemorySwipeService: SwipeConfigurationServicing {
    private var storedConfiguration: SwipeConfiguration
    private var continuation: AsyncStream<SwipeConfiguration>.Continuation?

    init(initial: SwipeConfiguration) {
        storedConfiguration = initial
    }

    func load() async -> SwipeConfiguration { storedConfiguration }

    func save(_ configuration: SwipeConfiguration) async throws {
        storedConfiguration = configuration
        continuation?.yield(configuration)
    }

    nonisolated func updatesStream() -> AsyncStream<SwipeConfiguration> {
        AsyncStream { continuation in
            Task { await self.storeContinuation(continuation) }
        }
    }

    private func storeContinuation(_ continuation: AsyncStream<SwipeConfiguration>.Continuation) {
        self.continuation = continuation
    }
}

actor InMemoryPlaybackService: PlaybackConfigurationServicing {
    private var stored: PlaybackSettings
    private var continuation: AsyncStream<PlaybackSettings>.Continuation?

    init(initial: PlaybackSettings) {
        stored = initial
    }

    func load() async -> PlaybackSettings { stored }

    func save(_ settings: PlaybackSettings) async {
        stored = settings
        continuation?.yield(settings)
    }

    nonisolated func updatesStream() -> AsyncStream<PlaybackSettings> {
        AsyncStream { continuation in
            Task { await self.storeContinuation(continuation) }
        }
    }

    private func storeContinuation(_ continuation: AsyncStream<PlaybackSettings>.Continuation) {
        self.continuation = continuation
    }
}

actor InMemoryDownloadService: DownloadConfigurationServicing {
    private var stored: DownloadSettings
    private var continuation: AsyncStream<DownloadSettings>.Continuation?

    init(initial: DownloadSettings) {
        stored = initial
    }

    func load() async -> DownloadSettings { stored }

    func save(_ settings: DownloadSettings) async {
        stored = settings
        continuation?.yield(settings)
    }

    nonisolated func updatesStream() -> AsyncStream<DownloadSettings> {
        AsyncStream { continuation in
            Task { await self.storeContinuation(continuation) }
        }
    }

    private func storeContinuation(_ continuation: AsyncStream<DownloadSettings>.Continuation) {
        self.continuation = continuation
    }
}

actor InMemoryNotificationsService: NotificationsConfigurationServicing {
    private var stored: NotificationSettings
    private var continuation: AsyncStream<NotificationSettings>.Continuation?

    init(initial: NotificationSettings) {
        self.stored = initial
    }

    func load() async -> NotificationSettings { stored }

    func save(_ settings: NotificationSettings) async {
        stored = settings
        continuation?.yield(settings)
    }

    nonisolated func updatesStream() -> AsyncStream<NotificationSettings> {
        AsyncStream { continuation in
            Task { await self.storeContinuation(continuation) }
        }
    }

    private func storeContinuation(_ continuation: AsyncStream<NotificationSettings>.Continuation) {
        self.continuation = continuation
    }
}

actor InMemoryAppearanceService: AppearanceConfigurationServicing {
    private var stored: AppearanceSettings
    private var continuation: AsyncStream<AppearanceSettings>.Continuation?

    init(initial: AppearanceSettings) {
        stored = initial
    }

    func load() async -> AppearanceSettings { stored }

    func save(_ settings: AppearanceSettings) async {
        stored = settings
        continuation?.yield(settings)
    }

    nonisolated func updatesStream() -> AsyncStream<AppearanceSettings> {
        AsyncStream { continuation in
            Task { await self.storeContinuation(continuation) }
        }
    }

    private func storeContinuation(_ continuation: AsyncStream<AppearanceSettings>.Continuation) {
        self.continuation = continuation
    }
}

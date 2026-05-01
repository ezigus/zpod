import XCTest
import Foundation
#if canImport(Combine)
@preconcurrency import CombineSupport
#endif
@testable import Networking
import CoreModels
import Persistence
import SharedUtilities
import TestSupport

// Simple mock implementations for testing
final class SimpleFeedDataLoader: FeedDataLoading {
    var mockData: Data = Data()
    var shouldThrow = false
    var loadCalled = false
    
    func load(url: URL) async throws -> Data {
        loadCalled = true
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return mockData
    }
}

final class SimpleFeedParser: FeedParsing {
    var mockParsedFeed: ParsedFeed?
    var shouldThrow = false
    var parseCalled = false
    
    func parse(data: Data, sourceURL: URL) throws -> ParsedFeed {
        parseCalled = true
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return mockParsedFeed ?? ParsedFeed(podcast: Podcast(id: "default", title: "Default", feedURL: sourceURL))
    }
}

final class SimplePodcastManager: PodcastManaging {
    private let lock = NSLock()
    private var podcasts: [Podcast] = []
    private var recordedAddCall = false
    private var recordedRemoveCall = false

    var addPodcastCalled: Bool {
        lock.lock(); defer { lock.unlock() }
        return recordedAddCall
    }

    var removePodcastCalled: Bool {
        lock.lock(); defer { lock.unlock() }
        return recordedRemoveCall
    }

    func all() -> [Podcast] {
        lock.lock(); defer { lock.unlock() }
        return podcasts
    }

    func find(id: String) -> Podcast? {
        lock.lock(); defer { lock.unlock() }
        return podcasts.first { $0.id == id }
    }

    func add(_ podcast: Podcast) {
        lock.lock()
        recordedAddCall = true
        podcasts.append(podcast)
        lock.unlock()
    }

    func update(_ podcast: Podcast) {
        lock.lock()
        if let index = podcasts.firstIndex(where: { $0.id == podcast.id }) {
            podcasts[index] = podcast
        }
        lock.unlock()
    }

    func remove(id: String) {
        lock.lock()
        recordedRemoveCall = true
        podcasts.removeAll { $0.id == id }
        lock.unlock()
    }

    func findByFolder(folderId: String) -> [Podcast] { [] }
    func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] { [] }
    func findByTag(tagId: String) -> [Podcast] { [] }
    func findUnorganized() -> [Podcast] { [] }
    func fetchOrphanedEpisodes() -> [Episode] { [] }
    func deleteOrphanedEpisode(id: String) -> Bool { false }
    func deleteAllOrphanedEpisodes() -> Int { 0 }
}

extension SimplePodcastManager: @unchecked Sendable {}

private actor MockPodcastSettingsRepository: SettingsRepository {
    private var stored: [String: PodcastDownloadSettings] = [:]

    func loadPodcastDownloadSettings(podcastId: String) async -> PodcastDownloadSettings? { stored[podcastId] }
    func savePodcastDownloadSettings(_ settings: PodcastDownloadSettings) async { stored[settings.podcastId] = settings }
    func removePodcastDownloadSettings(podcastId: String) async { stored.removeValue(forKey: podcastId) }
    func loadGlobalDownloadSettings() async -> DownloadSettings { .default }
    func saveGlobalDownloadSettings(_ settings: DownloadSettings) async {}
    func loadGlobalNotificationSettings() async -> NotificationSettings { .default }
    func saveGlobalNotificationSettings(_ settings: NotificationSettings) async {}
    func loadGlobalPlaybackSettings() async -> PlaybackSettings { PlaybackSettings() }
    func saveGlobalPlaybackSettings(_ settings: PlaybackSettings) async {}
    func loadGlobalUISettings() async -> UISettings { .default }
    func saveGlobalUISettings(_ settings: UISettings) async {}
    func loadGlobalAppearanceSettings() async -> AppearanceSettings { .default }
    func saveGlobalAppearanceSettings(_ settings: AppearanceSettings) async {}
    func loadSmartListAutomationSettings() async -> SmartListRefreshConfiguration { SmartListRefreshConfiguration() }
    func saveSmartListAutomationSettings(_ settings: SmartListRefreshConfiguration) async {}
    func loadPlaybackPresetLibrary() async -> PlaybackPresetLibrary { .default }
    func savePlaybackPresetLibrary(_ library: PlaybackPresetLibrary) async {}
    func loadPodcastPlaybackSettings(podcastId: String) async -> PodcastPlaybackSettings? { nil }
    func savePodcastPlaybackSettings(podcastId: String, _ settings: PodcastPlaybackSettings) async {}
    func removePodcastPlaybackSettings(podcastId: String) async {}
    func loadPlaybackResumeState() async -> PlaybackResumeState? { nil }
    func savePlaybackResumeState(_ state: PlaybackResumeState) async {}
    func clearPlaybackResumeState() async {}
    func settingsChangeStream() async -> AsyncStream<SettingsChange> { AsyncStream { _ in } }
}

final class SimpleNetworkingTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // All tests in this class use pure in-memory mocks and should complete in
        // milliseconds. A 30-second limit prevents actor-isolation deadlocks from
        // silently blocking the entire Networking package test run (~39 min hang
        // observed without this bound).
        executionTimeAllowance = 30
    }

    func testSubscriptionService_validURL_success() async throws {
        // Given: Mock dependencies and subscription service
        let mockDataLoader = SimpleFeedDataLoader()
        let mockParser = SimpleFeedParser()
        let mockPodcastManager = SimplePodcastManager()
        
        let subscriptionService = SubscriptionService(
            dataLoader: mockDataLoader,
            parser: mockParser,
            podcastManager: mockPodcastManager
        )
        
        // Given: Valid URL and successful parsing
        let testURL = "https://example.com/feed.xml"
        let testPodcast = Podcast(id: "test-id", title: "Test Podcast", feedURL: URL(string: testURL)!)
        mockDataLoader.mockData = Data("mock feed data".utf8)
        mockParser.mockParsedFeed = ParsedFeed(podcast: testPodcast)
        
        // When: Subscribing to podcast
        let result = try await subscriptionService.subscribe(urlString: testURL)
        
        // Then: Should succeed
        XCTAssertEqual(result.id, testPodcast.id)
        XCTAssertEqual(result.title, testPodcast.title)
        XCTAssertTrue(mockDataLoader.loadCalled)
        XCTAssertTrue(mockParser.parseCalled)
        XCTAssertTrue(mockPodcastManager.addPodcastCalled)
    }
    
    func testSubscriptionService_invalidURL_throwsError() async {
        // Given: Subscription service with invalid URL
        let mockDataLoader = SimpleFeedDataLoader()
        let mockParser = SimpleFeedParser()
        let mockPodcastManager = SimplePodcastManager()
        
        let subscriptionService = SubscriptionService(
            dataLoader: mockDataLoader,
            parser: mockParser,
            podcastManager: mockPodcastManager
        )
        
        let invalidURL = "not-a-valid-url"
        
        // When & Then: Should throw invalidURL error
        do {
            _ = try await subscriptionService.subscribe(urlString: invalidURL)
            XCTFail("Expected invalidURL error")
        } catch SubscriptionService.Error.invalidURL {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testAutoDownloadService_enablesDownload() {
        // Given: Auto-download service
        let queueManager = InMemoryDownloadQueueManager()
        let autoDownloadService = AutoDownloadService(queueManager: queueManager)
        
        let podcastId = "test-podcast"
        
        // When: Enabling auto-download
        autoDownloadService.setAutoDownload(enabled: true, for: podcastId)
        
        // When: New episode detected
        let episode = Episode(id: "ep1", title: "New Episode")
        let podcast = Podcast(id: podcastId, title: "Test Podcast", feedURL: URL(string: "https://example.com")!)
        autoDownloadService.onNewEpisodeDetected(episode: episode, podcast: podcast)
        
        // Then: Episode should be queued
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.episodeId, episode.id)
    }
    
    @MainActor
    func testDownloadQueueManager_addAndRetrieveTasks() {
        // Given: Download queue manager
        let queueManager = InMemoryDownloadQueueManager()
        
        // When: Adding task to queue
        let task = MockDownloadTask.createSample(id: "task1", title: "Episode 1")
        queueManager.addToQueue(task)
        
        // Then: Task should be in queue
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.id, "task1")
        XCTAssertEqual(queue.first?.title, "Episode 1")
    }
    
    @MainActor
    func testDownloadCoordinator_initialization() {
        // Given: Download coordinator with queue manager
        let queueManager = InMemoryDownloadQueueManager()
        let downloadCoordinator = DownloadCoordinator(queueManager: queueManager)
        
        // Then: Should be properly initialized
        XCTAssertNotNil(downloadCoordinator)
    }
    
    @MainActor
    func testDownloadQueue_priorityOrdering() {
        // Given: Download queue manager
        let queueManager = InMemoryDownloadQueueManager()

        // When: Adding tasks with different priorities
        let lowPriorityTask = MockDownloadTask.createSample(id: "low", title: "Low Priority", priority: .low)
        let highPriorityTask = MockDownloadTask.createSample(id: "high", title: "High Priority", priority: .high)

        queueManager.addToQueue(lowPriorityTask)
        queueManager.addToQueue(highPriorityTask)

        // Then: Queue should maintain priority order
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 2)
        // High priority should come first
        XCTAssertEqual(queue.first?.id, "high")
    }

    @MainActor
    func testDownloadCoordinator_addDownload_priorityMapping() {
        // Given: Download coordinator
        let queueManager = InMemoryDownloadQueueManager()
        let coordinator = DownloadCoordinator(queueManager: queueManager)

        let episode = Episode(id: "ep-manual", title: "Manual Episode")

        // When: Adding with negative priority (low)
        coordinator.addDownload(for: episode, priority: -5)
        XCTAssertEqual(queueManager.getCurrentQueue().first?.priority, .low)

        // When: Adding with zero priority (normal)
        queueManager.removeFromQueue(taskId: queueManager.getCurrentQueue().first!.id)
        coordinator.addDownload(for: episode, priority: 0)
        XCTAssertEqual(queueManager.getCurrentQueue().first?.priority, .normal)

        // When: Adding with positive priority (high)
        queueManager.removeFromQueue(taskId: queueManager.getCurrentQueue().first!.id)
        coordinator.addDownload(for: episode, priority: 5)
        XCTAssertEqual(queueManager.getCurrentQueue().first?.priority, .high)

        // When: Adding with default priority (5 → high — manual downloads are elevated by default)
        queueManager.removeFromQueue(taskId: queueManager.getCurrentQueue().first!.id)
        coordinator.addDownload(for: episode)
        XCTAssertEqual(queueManager.getCurrentQueue().first?.priority, .high)
    }

    @MainActor
    func testAutoDownloadService_loadsPriorityFromRepository() async {
        // Given: In-memory mock repository with a stored high priority (avoids real UserDefaults I/O)
        let repo = MockPodcastSettingsRepository()

        let podcastId = "priority-podcast"
        let settings = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: nil,
            wifiOnly: nil,
            retentionPolicy: nil,
            priority: 7
        )
        await repo.savePodcastDownloadSettings(settings)

        let queueManager = InMemoryDownloadQueueManager()
        let service = AutoDownloadService(queueManager: queueManager, settingsRepository: repo)
        service.setAutoDownload(enabled: true, for: podcastId)

        let episode = Episode(id: "ep-priority", title: "Priority Episode")
        let podcast = Podcast(id: podcastId, title: "Priority Podcast", feedURL: URL(string: "https://example.com")!)

        // When: New episode detected (priority not yet in memory cache).
        // onNewEpisodeDetected returns the async Task it spawns; awaiting .value suspends
        // the test cooperatively, allowing the @MainActor task to run without blocking
        // the main thread (which would deadlock with run-loop-based expectation waiting).
        let enqueueTask = service.onNewEpisodeDetected(episode: episode, podcast: podcast)
        await enqueueTask?.value

        // Then: Episode queued with high priority from storage
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.episodeId, episode.id)
        XCTAssertEqual(queue.first?.priority, .high)
        // Verify the priority was cached in service memory
        XCTAssertEqual(service.getPriority(for: podcastId), 7)
    }

    // MARK: - convertPriorityToEnum Boundary Tests

    @MainActor
    func testConvertPriorityToEnum_negativeMapsToLow() {
        XCTAssertEqual(AutoDownloadService.convertPriorityToEnum(-10), .low)
        XCTAssertEqual(AutoDownloadService.convertPriorityToEnum(-5), .low)
        XCTAssertEqual(AutoDownloadService.convertPriorityToEnum(-1), .low)
    }

    @MainActor
    func testConvertPriorityToEnum_zeroMapsToNormal() {
        XCTAssertEqual(AutoDownloadService.convertPriorityToEnum(0), .normal)
    }

    @MainActor
    func testConvertPriorityToEnum_positiveMapsToHigh() {
        XCTAssertEqual(AutoDownloadService.convertPriorityToEnum(1), .high)
        XCTAssertEqual(AutoDownloadService.convertPriorityToEnum(5), .high)
        XCTAssertEqual(AutoDownloadService.convertPriorityToEnum(10), .high)
    }
}

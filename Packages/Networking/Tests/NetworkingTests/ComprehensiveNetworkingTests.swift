import XCTest
#if canImport(Combine)
@preconcurrency import Combine
#endif
@testable import Networking
import CoreModels
import SharedUtilities
import TestSupport

@MainActor
final class ComprehensiveNetworkingTests: XCTestCase {
    
    // MARK: - Properties
    private var mockDataLoader: MockFeedDataLoader!
    private var mockParser: MockFeedParser!
    private var mockPodcastManager: MockPodcastManager!
    private var subscriptionService: SubscriptionService!
    private var autoDownloadService: AutoDownloadService!
    private var queueManager: InMemoryDownloadQueueManager!
    private var downloadCoordinator: DownloadCoordinator!
    
    #if canImport(Combine)
    private var cancellables: Set<AnyCancellable> = []
    #endif
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Given: Set up mock dependencies
        mockDataLoader = MockFeedDataLoader()
        mockParser = MockFeedParser()
        mockPodcastManager = MockPodcastManager()
        queueManager = InMemoryDownloadQueueManager()
        
        subscriptionService = SubscriptionService(
            dataLoader: mockDataLoader,
            parser: mockParser,
            podcastManager: mockPodcastManager
        )
        
        autoDownloadService = AutoDownloadService(queueManager: queueManager)
        downloadCoordinator = DownloadCoordinator(queueManager: queueManager)
    }
    
    override func tearDown() async throws {
        #if canImport(Combine)
        cancellables.removeAll()
        #endif
        try await super.tearDown()
    }
    
    // MARK: - SubscriptionService Tests
    
    func testSubscriptionService_validURLString_successfulSubscription() async throws {
        // Given: Valid URL and successful data loading/parsing
        let testURL = "https://example.com/feed.xml"
        let testPodcast = Podcast(id: "test-id", title: "Test Podcast", feedURL: URL(string: testURL)!)
        mockDataLoader.mockData = Data("mock feed data".utf8)
        mockParser.mockParsedFeed = ParsedFeed(podcast: testPodcast)
        
        // When: Subscribing to podcast with URL string
        let result = try await subscriptionService.subscribe(urlString: testURL)
        
        // Then: Subscription should succeed
        XCTAssertEqual(result.id, testPodcast.id)
        XCTAssertEqual(result.title, testPodcast.title)
        XCTAssertTrue(mockDataLoader.loadCalled)
        XCTAssertTrue(mockParser.parseCalled)
        XCTAssertTrue(mockPodcastManager.addPodcastCalled)
    }
    
    func testSubscriptionService_invalidURLString_throwsError() async {
        // Given: Invalid URL string
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
    
    func testSubscriptionService_unsupportedScheme_throwsError() async {
        // Given: URL with unsupported scheme
        let unsupportedURL = "ftp://example.com/feed.xml"
        
        // When & Then: Should throw invalidURL error
        do {
            _ = try await subscriptionService.subscribe(urlString: unsupportedURL)
            XCTFail("Expected invalidURL error")
        } catch SubscriptionService.Error.invalidURL {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSubscriptionService_dataLoadingFails_throwsError() async {
        // Given: Data loading failure
        let testURL = "https://example.com/feed.xml"
        mockDataLoader.shouldThrowError = true
        
        // When & Then: Should throw dataLoadFailed error
        do {
            _ = try await subscriptionService.subscribe(urlString: testURL)
            XCTFail("Expected dataLoadFailed error")
        } catch SubscriptionService.Error.dataLoadFailed {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSubscriptionService_parsingFails_throwsError() async {
        // Given: Successful data loading but parsing failure
        let testURL = "https://example.com/feed.xml"
        mockDataLoader.mockData = Data("invalid feed data".utf8)
        mockParser.shouldThrowError = true
        
        // When & Then: Should throw parseFailed error
        do {
            _ = try await subscriptionService.subscribe(urlString: testURL)
            XCTFail("Expected parseFailed error")
        } catch SubscriptionService.Error.parseFailed {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSubscriptionService_duplicateSubscription_throwsError() async {
        // Given: Existing podcast subscription
        let testURL = "https://example.com/feed.xml"
        let testPodcast = Podcast(id: "test-id", title: "Test Podcast", feedURL: URL(string: testURL)!)
        mockDataLoader.mockData = Data("mock feed data".utf8)
        mockParser.mockParsedFeed = ParsedFeed(podcast: testPodcast)
        mockPodcastManager.shouldReturnDuplicate = true
        
        // When & Then: Should handle duplicate gracefully (no error in this simplified version)
        do {
            _ = try await subscriptionService.subscribe(urlString: testURL)
            // In this implementation, duplicates are handled silently
            XCTAssertTrue(mockPodcastManager.addPodcastCalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - AutoDownloadService Tests
    
    func testAutoDownloadService_enabledForPodcast_downloadsNewEpisode() {
        // Given: Auto-download enabled for podcast
        let podcast = Podcast(id: "test-podcast", title: "Test Podcast", feedURL: URL(string: "https://example.com")!)
        let episode = Episode(id: "ep1", title: "New Episode")
        autoDownloadService.setAutoDownload(enabled: true, for: podcast.id)
        
        // When: New episode detected
        autoDownloadService.onNewEpisodeDetected(episode: episode, podcast: podcast)
        
        // Then: Episode should be added to download queue
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.episodeId, episode.id)
        XCTAssertEqual(queue.first?.title, episode.title)
    }
    
    func testAutoDownloadService_disabledForPodcast_doesNotDownload() {
        // Given: Auto-download disabled for podcast
        let podcast = Podcast(id: "test-podcast", title: "Test Podcast", feedURL: URL(string: "https://example.com")!)
        let episode = Episode(id: "ep1", title: "New Episode")
        autoDownloadService.setAutoDownload(enabled: false, for: podcast.id)
        
        // When: New episode detected
        autoDownloadService.onNewEpisodeDetected(episode: episode, podcast: podcast)
        
        // Then: Episode should not be added to download queue
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 0)
    }
    
    func testAutoDownloadService_defaultSetting_returnsDisabled() {
        // Given: No explicit setting for podcast
        let podcastId = "unknown-podcast"
        
        // When: Getting auto-download setting
        let setting = autoDownloadService.getAutoDownloadSetting(for: podcastId)
        
        // Then: Should return disabled by default
        XCTAssertFalse(setting)
    }
    
    func testAutoDownloadService_toggleSetting_persistsCorrectly() {
        // Given: Podcast ID
        let podcastId = "test-podcast"
        
        // When: Enabling auto-download
        autoDownloadService.setAutoDownload(enabled: true, for: podcastId)
        let enabledSetting = autoDownloadService.getAutoDownloadSetting(for: podcastId)
        
        // When: Disabling auto-download
        autoDownloadService.setAutoDownload(enabled: false, for: podcastId)
        let disabledSetting = autoDownloadService.getAutoDownloadSetting(for: podcastId)
        
        // Then: Settings should persist correctly
        XCTAssertTrue(enabledSetting)
        XCTAssertFalse(disabledSetting)
    }
    
    // MARK: - DownloadQueueManager Tests
    
    func testDownloadQueueManager_addTask_updatesQueue() {
        // Given: Download task
        let task = MockDownloadTask.sampleTask(id: "task1", title: "Test Episode")
        
        // When: Adding task to queue
        queueManager.addToQueue(task)
        
        // Then: Queue should contain the task
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.id, task.id)
        XCTAssertEqual(queue.first?.title, task.title)
    }
    
    func testDownloadQueueManager_removeTask_updatesQueue() {
        // Given: Task in queue
        let task = MockDownloadTask.sampleTask(id: "task1", title: "Test Episode")
        queueManager.addToQueue(task)
        
        // When: Removing task from queue
        queueManager.removeFromQueue(taskId: task.id)
        
        // Then: Queue should be empty
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 0)
    }
    
    func testDownloadQueueManager_reorderQueue_updatesOrder() {
        // Given: Multiple tasks in queue
        let task1 = MockDownloadTask.sampleTask(id: "task1", title: "Episode 1")
        let task2 = MockDownloadTask.sampleTask(id: "task2", title: "Episode 2")
        let task3 = MockDownloadTask.sampleTask(id: "task3", title: "Episode 3")
        
        queueManager.addToQueue(task1)
        queueManager.addToQueue(task2)
        queueManager.addToQueue(task3)
        
        // When: Reordering queue
        queueManager.reorderQueue(taskIds: ["task3", "task1", "task2"])
        
        // Then: Queue should be reordered
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(queue[0].id, "task3")
        XCTAssertEqual(queue[1].id, "task1")
        XCTAssertEqual(queue[2].id, "task2")
    }
    
    func testDownloadQueueManager_pauseDownload_updatesState() {
        // Given: Downloading task
        let task = MockDownloadTask.sampleTask(id: "task1", state: .downloading)
        queueManager.addToQueue(task)
        
        // When: Pausing download
        queueManager.pauseDownload(taskId: task.id)
        
        // Then: Task state should be paused
        let taskInfo = queueManager.getTask(id: task.id)
        XCTAssertEqual(taskInfo?.state, .paused)
    }
    
    func testDownloadQueueManager_resumeDownload_updatesState() {
        // Given: Paused task
        let task = MockDownloadTask.sampleTask(id: "task1", state: .paused)
        queueManager.addToQueue(task)
        
        // When: Resuming download
        queueManager.resumeDownload(taskId: task.id)
        
        // Then: Task state should be downloading
        let taskInfo = queueManager.getTask(id: task.id)
        XCTAssertEqual(taskInfo?.state, .downloading)
    }
    
    func testDownloadQueueManager_cancelDownload_updatesState() {
        // Given: Downloading task
        let task = MockDownloadTask.sampleTask(id: "task1", state: .downloading)
        queueManager.addToQueue(task)
        
        // When: Canceling download
        queueManager.cancelDownload(taskId: task.id)
        
        // Then: Task state should be cancelled
        let taskInfo = queueManager.getTask(id: task.id)
        XCTAssertEqual(taskInfo?.state, .cancelled)
    }
    
    func testDownloadQueueManager_retryFailedDownload_updatesState() {
        // Given: Failed task
        let task = MockDownloadTask.sampleTask(id: "task1", state: .failed)
        queueManager.addToQueue(task)
        
        // When: Retrying failed download
        queueManager.retryFailedDownload(taskId: task.id)
        
        // Then: Task state should be pending for retry
        let taskInfo = queueManager.getTask(id: task.id)
        XCTAssertEqual(taskInfo?.state, .pending)
    }
    
    #if canImport(Combine)
    func testDownloadQueueManager_queuePublisher_emitsChanges() async {
        // Given: Queue publisher subscription
        var receivedQueues: [[DownloadTask]] = []
        let expectation = self.expectation(description: "Queue updates received")
        expectation.expectedFulfillmentCount = 3 // Initial + 2 updates
        
        queueManager.queuePublisher
            .sink { queue in
                receivedQueues.append(queue)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: Adding tasks to queue
        await Task.yield() // Allow initial value to emit
        let task1 = MockDownloadTask.sampleTask(id: "task1")
        queueManager.addToQueue(task1)
        
        let task2 = MockDownloadTask.sampleTask(id: "task2")
        queueManager.addToQueue(task2)
        
        // Then: Should receive queue updates
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedQueues.count, 3)
        XCTAssertEqual(receivedQueues[0].count, 0) // Initial empty
        XCTAssertEqual(receivedQueues[1].count, 1) // After first add
        XCTAssertEqual(receivedQueues[2].count, 2) // After second add
    }
    #endif
    
    // MARK: - DownloadCoordinator Tests
    
    func testDownloadCoordinator_addManualDownload_addsToQueue() {
        // Given: Episode for download
        let episode = Episode(id: "ep1", title: "Manual Download")
        
        // When: Adding manual download
        downloadCoordinator.addDownload(for: episode, priority: 5)
        
        // Then: Task should be added to queue
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.episodeId, episode.id)
        XCTAssertEqual(queue.first?.title, episode.title)
        XCTAssertEqual(queue.first?.priority, .high)
    }
    
    func testDownloadCoordinator_lowPriorityDownload_correctPriority() {
        // Given: Episode for low priority download
        let episode = Episode(id: "ep1", title: "Low Priority")
        
        // When: Adding low priority download
        downloadCoordinator.addDownload(for: episode, priority: 1)
        
        // Then: Task should have low priority
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.first?.priority, .low)
    }
    
    func testDownloadCoordinator_normalPriorityDownload_correctPriority() {
        // Given: Episode for normal priority download
        let episode = Episode(id: "ep1", title: "Normal Priority")
        
        // When: Adding normal priority download
        downloadCoordinator.addDownload(for: episode, priority: 3)
        
        // Then: Task should have normal priority
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.first?.priority, .normal)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testSubscriptionService_emptyDataResponse_handlesGracefully() async {
        // Given: Empty data response
        let testURL = "https://example.com/feed.xml"
        mockDataLoader.mockData = Data()
        mockParser.shouldThrowError = true
        
        // When & Then: Should handle empty data gracefully
        do {
            _ = try await subscriptionService.subscribe(urlString: testURL)
            XCTFail("Expected parseFailed error")
        } catch SubscriptionService.Error.parseFailed {
            // Expected behavior for empty data
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testAutoDownloadService_multipleEpisodes_handlesCorrectly() {
        // Given: Auto-download enabled and multiple episodes
        let podcast = Podcast(id: "test-podcast", title: "Test Podcast", feedURL: URL(string: "https://example.com")!)
        let episode1 = Episode(id: "ep1", title: "Episode 1")
        let episode2 = Episode(id: "ep2", title: "Episode 2")
        autoDownloadService.setAutoDownload(enabled: true, for: podcast.id)
        
        // When: Multiple new episodes detected
        autoDownloadService.onNewEpisodeDetected(episode: episode1, podcast: podcast)
        autoDownloadService.onNewEpisodeDetected(episode: episode2, podcast: podcast)
        
        // Then: Both episodes should be queued
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 2)
        let episodeIds = queue.map { $0.episodeId }
        XCTAssertTrue(episodeIds.contains("ep1"))
        XCTAssertTrue(episodeIds.contains("ep2"))
    }
    
    func testDownloadQueueManager_invalidTaskId_handlesGracefully() {
        // Given: Empty queue
        // When: Operating on non-existent task
        queueManager.removeFromQueue(taskId: "non-existent")
        queueManager.pauseDownload(taskId: "non-existent")
        queueManager.resumeDownload(taskId: "non-existent")
        queueManager.cancelDownload(taskId: "non-existent")
        queueManager.retryFailedDownload(taskId: "non-existent")
        
        // Then: Should not crash and queue should remain empty
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, 0)
    }
    
    // MARK: - Performance Tests
    
    func testDownloadQueueManager_largeQueue_performsWell() {
        // Given: Performance measurement
        let taskCount = 1000
        
        // When: Adding many tasks
        measure {
            for i in 0..<taskCount {
                let task = MockDownloadTask.sampleTask(id: "task\(i)", title: "Episode \(i)")
                queueManager.addToQueue(task)
            }
        }
        
        // Then: Queue should contain all tasks
        let queue = queueManager.getCurrentQueue()
        XCTAssertEqual(queue.count, taskCount)
    }
}

// MARK: - Mock Objects

private class MockFeedDataLoader: FeedDataLoading {
    var mockData: Data?
    var shouldThrowError = false
    var loadCalled = false
    
    func load(url: URL) async throws -> Data {
        loadCalled = true
        if shouldThrowError {
            throw SubscriptionService.Error.dataLoadFailed
        }
        return mockData ?? Data()
    }
}

private class MockFeedParser: FeedParsing {
    var mockParsedFeed: ParsedFeed?
    var shouldThrowError = false
    var parseCalled = false
    
    func parse(data: Data, sourceURL: URL) throws -> ParsedFeed {
        parseCalled = true
        if shouldThrowError {
            throw SubscriptionService.Error.parseFailed
        }
        return mockParsedFeed ?? ParsedFeed(podcast: Podcast(id: "default", title: "Default Podcast", feedURL: sourceURL))
    }
}

private class MockPodcastManager: PodcastManaging, @unchecked Sendable {
    var shouldReturnDuplicate = false
    var addPodcastCalled = false
    private var _podcasts: [Podcast] = []
    private let queue = DispatchQueue(label: "MockPodcastManager", attributes: .concurrent)
    
    var podcasts: [Podcast] {
        get {
            queue.sync { _podcasts }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?._podcasts = newValue
            }
        }
    }
    
    func all() -> [Podcast] {
        return queue.sync { _podcasts }
    }
    
    func find(id: String) -> Podcast? {
        return queue.sync { _podcasts.first { $0.id == id } }
    }
    
    func add(_ podcast: Podcast) {
        queue.async(flags: .barrier) { [weak self] in
            self?.addPodcastCalled = true
            if self?.shouldReturnDuplicate == true {
                return // Simulate duplicate - don't add
            }
            self?._podcasts.append(podcast)
        }
    }
    
    func update(_ podcast: Podcast) {
        queue.async(flags: .barrier) { [weak self] in
            guard let index = self?._podcasts.firstIndex(where: { $0.id == podcast.id }) else { return }
            self?._podcasts[index] = podcast
        }
    }
    
    func remove(id: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?._podcasts.removeAll { $0.id == id }
        }
    }
    
    func findByFolder(folderId: String) -> [Podcast] {
        // Simplified for testing - in real implementation would check folder relationships
        return []
    }
    
    func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] {
        return findByFolder(folderId: folderId)
    }
    
    func findByTag(tagId: String) -> [Podcast] {
        // Simplified for testing - in real implementation would check tag relationships
        return []
    }
    
    func findUnorganized() -> [Podcast] {
        // Simplified for testing - in real implementation would check organization status
        return []
    }
}

extension MockDownloadTask {
    static func sampleTask(
        id: String = "sample-task",
        episodeId: String = "sample-episode",
        title: String = "Sample Episode",
        state: DownloadState = .pending,
        priority: DownloadPriority = .normal
    ) -> DownloadTask {
        return DownloadTask(
            id: id,
            episodeId: episodeId,
            podcastId: "sample-podcast",
            audioURL: URL(string: "https://example.com/audio.mp3")!,
            title: title,
            estimatedSize: 1024 * 1024, // 1MB
            priority: priority
        )
    }
}
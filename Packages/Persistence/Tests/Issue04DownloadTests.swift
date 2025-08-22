#if canImport(Combine)
@preconcurrency import Combine
#endif
import XCTest
@testable import Persistence

final class Issue04DownloadTests: XCTestCase {
  var cancellables: Set<AnyCancellable>!

  override func setUp() {
    super.setUp()
    cancellables = Set<AnyCancellable>()
  }

  override func tearDown() {
    cancellables = nil
    super.tearDown()
  }

  // MARK: - DownloadTask Model Tests

  func testDownloadTaskInitialization() {
    let task = DownloadTask(
      id: "task1",
      episodeId: "ep1",
      podcastId: "pod1",
      state: .pending,
      priority: 5
    )

    XCTAssertEqual(task.id, "task1")
    XCTAssertEqual(task.episodeId, "ep1")
    XCTAssertEqual(task.podcastId, "pod1")
    XCTAssertEqual(task.state, .pending)
    XCTAssertEqual(task.priority, 5)
    XCTAssertEqual(task.progress, 0.0)
    XCTAssertEqual(task.retryCount, 0)
    XCTAssertNil(task.error)
  }

  func testDownloadTaskStateTransitions() {
    var task = DownloadTask(
      id: "task1", episodeId: "ep1", podcastId: "pod1", state: .pending, priority: 1)

    // Test transition to downloading
    task = task.withState(.downloading)
    XCTAssertEqual(task.state, .downloading)

    // Test transition to completed
    task = task.withState(.completed)
    XCTAssertEqual(task.state, .completed)

    // Test transition to failed with error
    let error = DownloadError.networkFailure("Connection timeout")
    task = task.withState(.failed)
    task = task.withError(error)
    XCTAssertEqual(task.state, .failed)
    XCTAssertEqual(task.error?.localizedDescription, error.localizedDescription)
  }

  // MARK: - DownloadQueueManager Tests

  @MainActor
  func testQueueManagerAddTask() {
    let queueManager = InMemoryDownloadQueueManager()
    let task = createTestTask(id: "task1", priority: 5)

    queueManager.addToQueue(task)

    let queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue.count, 1)
    XCTAssertEqual(queue.first?.id, "task1")
  }

  @MainActor
  func testQueueManagerPriorityOrdering() {
    let queueManager = InMemoryDownloadQueueManager()
    let lowPriorityTask = createTestTask(id: "low", priority: 1)
    let highPriorityTask = createTestTask(id: "high", priority: 10)
    let mediumPriorityTask = createTestTask(id: "medium", priority: 5)

    queueManager.addToQueue(lowPriorityTask)
    queueManager.addToQueue(highPriorityTask)
    queueManager.addToQueue(mediumPriorityTask)

    let queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue.count, 3)
    XCTAssertEqual(queue[0].id, "high")  // Highest priority first
    XCTAssertEqual(queue[1].id, "medium")
    XCTAssertEqual(queue[2].id, "low")
  }

  @MainActor
  func testQueueManagerReorderTasks() {
    let queueManager = InMemoryDownloadQueueManager()
    let task1 = createTestTask(id: "task1", priority: 1)
    let task2 = createTestTask(id: "task2", priority: 2)
    let task3 = createTestTask(id: "task3", priority: 3)

    queueManager.addToQueue(task1)
    queueManager.addToQueue(task2)
    queueManager.addToQueue(task3)

    // Reorder: task1 should be first now
    queueManager.reorderQueue(taskIds: ["task1", "task3", "task2"])

    let queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue[0].id, "task1")
    XCTAssertEqual(queue[1].id, "task3")
    XCTAssertEqual(queue[2].id, "task2")
  }

  @MainActor
  func testQueueManagerRemoveTask() {
    let queueManager = InMemoryDownloadQueueManager()
    let task1 = createTestTask(id: "task1", priority: 1)
    let task2 = createTestTask(id: "task2", priority: 2)

    queueManager.addToQueue(task1)
    queueManager.addToQueue(task2)

    queueManager.removeFromQueue(taskId: "task1")

    let queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue.count, 1)
    XCTAssertEqual(queue.first?.id, "task2")
  }

  @MainActor
  func testQueueManagerPauseResumeCancel() {
    let queueManager = InMemoryDownloadQueueManager()
    let task = createTestTask(id: "task1", state: .downloading, priority: 1)

    queueManager.addToQueue(task)

    // Test pause
    queueManager.pauseDownload(taskId: "task1")
    let pausedTask = queueManager.getTask(id: "task1")
    XCTAssertEqual(pausedTask?.state, .paused)

    // Test resume
    queueManager.resumeDownload(taskId: "task1")
    let resumedTask = queueManager.getTask(id: "task1")
    XCTAssertEqual(resumedTask?.state, .downloading)

    // Test cancel
    queueManager.cancelDownload(taskId: "task1")
    let cancelledTask = queueManager.getTask(id: "task1")
    XCTAssertEqual(cancelledTask?.state, .cancelled)
  }

  @MainActor
  func testQueueManagerRetryFailedDownload() {
    let queueManager = InMemoryDownloadQueueManager()
    let task = createTestTask(id: "task1", state: .failed, priority: 1)

    queueManager.addToQueue(task)

    queueManager.retryFailedDownload(taskId: "task1")

    let retriedTask = queueManager.getTask(id: "task1")
    XCTAssertEqual(retriedTask?.state, .pending)
    XCTAssertEqual(retriedTask?.retryCount, 1)
  }

  @MainActor
  func testQueueManagerPublisher() {
    let queueManager = InMemoryDownloadQueueManager()
    let expectation = XCTestExpectation(description: "Queue updates published")
    var receivedQueues: [[DownloadTask]] = []

    queueManager.queuePublisher
      .sink { queue in
        receivedQueues.append(queue)
        if receivedQueues.count == 3 {  // Initial empty + 2 tasks
          expectation.fulfill()
        }
      }
      .store(in: &cancellables)

    let task1 = createTestTask(id: "task1", priority: 1)
    let task2 = createTestTask(id: "task2", priority: 2)

    queueManager.addToQueue(task1)
    queueManager.addToQueue(task2)

    wait(for: [expectation], timeout: 1.0)

    XCTAssertEqual(receivedQueues.count, 3)
    XCTAssertEqual(receivedQueues[0].count, 0)  // Initial empty
    XCTAssertEqual(receivedQueues[1].count, 1)  // After first task
    XCTAssertEqual(receivedQueues[2].count, 2)  // After second task
  }

  // MARK: - AutoDownloadService Tests

  @MainActor
  func testAutoDownloadServiceNewEpisodeDetection() {
    let queueManager = InMemoryDownloadQueueManager()
    let autoDownloadService = AutoDownloadService(queueManager: queueManager)

    let podcast = createTestPodcast(id: "pod1", autoDownloadEnabled: true)
    let episode = createTestEpisode(id: "ep1", podcastId: "pod1")

    autoDownloadService.onNewEpisodeDetected(episode: episode, podcast: podcast)

    let queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue.count, 1)
    XCTAssertEqual(queue.first?.episodeId, "ep1")
    XCTAssertEqual(queue.first?.podcastId, "pod1")
  }

  @MainActor
  func testAutoDownloadServiceDisabledPodcast() {
    let queueManager = InMemoryDownloadQueueManager()
    let autoDownloadService = AutoDownloadService(queueManager: queueManager)

    let podcast = createTestPodcast(id: "pod1", autoDownloadEnabled: false)
    let episode = createTestEpisode(id: "ep1", podcastId: "pod1")

    autoDownloadService.onNewEpisodeDetected(episode: episode, podcast: podcast)

    let queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue.count, 0)  // Should not auto-download
  }

  @MainActor
  func testAutoDownloadServiceExplicitSettings() {
    let queueManager = InMemoryDownloadQueueManager()
    let autoDownloadService = AutoDownloadService(queueManager: queueManager)

    // Test setting auto-download explicitly
    autoDownloadService.setAutoDownload(enabled: true, for: "pod1")
    XCTAssertTrue(autoDownloadService.getAutoDownloadSetting(for: "pod1"))

    autoDownloadService.setAutoDownload(enabled: false, for: "pod1")
    XCTAssertFalse(autoDownloadService.getAutoDownloadSetting(for: "pod1"))

    // Test default setting
    XCTAssertFalse(autoDownloadService.getAutoDownloadSetting(for: "unknownPodcast"))
  }

  @MainActor
  func testAutoDownloadServiceWithExplicitOverride() {
    let queueManager = InMemoryDownloadQueueManager()
    let autoDownloadService = AutoDownloadService(queueManager: queueManager)

    // Set explicit auto-download to true for unsubscribed podcast
    autoDownloadService.setAutoDownload(enabled: true, for: "pod1")

    let podcast = createTestPodcast(id: "pod1", autoDownloadEnabled: false)  // Not subscribed
    let episode = createTestEpisode(id: "ep1", podcastId: "pod1")

    autoDownloadService.onNewEpisodeDetected(episode: episode, podcast: podcast)

    let queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue.count, 1)  // Should download due to explicit setting
  }

  // MARK: - Integration Tests

  @MainActor
  func testIntegrationSubscriptionServiceWithAutoDownload() {
    // Test integration between subscription service and auto-download
    let queueManager = InMemoryDownloadQueueManager()
    let autoDownloadService = AutoDownloadService(queueManager: queueManager)
    let podcastManager = InMemoryPodcastManager()

    // Create a test podcast with episodes
    let episode1 = createTestEpisode(id: "ep1", title: "Episode 1", podcastId: "pod1")
    let episode2 = createTestEpisode(id: "ep2", title: "Episode 2", podcastId: "pod1")
    let podcast = Podcast(
      id: "pod1",
      title: "Test Podcast",
      feedURL: URL(string: "https://example.com/feed")!,
      episodes: [episode1, episode2],
      isSubscribed: true
    )

    // Enable auto-download for this podcast
    autoDownloadService.setAutoDownload(enabled: true, for: podcast.id)

    // Simulate new episodes being detected
    autoDownloadService.onNewEpisodeDetected(episode: episode1, podcast: podcast)
    autoDownloadService.onNewEpisodeDetected(episode: episode2, podcast: podcast)

    let queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue.count, 2)

    let episodeIds = queue.map { $0.episodeId }
    XCTAssertTrue(episodeIds.contains("ep1"))
    XCTAssertTrue(episodeIds.contains("ep2"))
  }

  @MainActor
  func testAcceptanceCriteriaNewEpisodesEnterQueueRespectingPriority() {
    // Acceptance Criteria: "New episodes marked for auto-download enter queue respecting priority"
    let queueManager = InMemoryDownloadQueueManager()
    let autoDownloadService = AutoDownloadService(queueManager: queueManager)

    // Add existing manual download with high priority
    let manualTask = createTestTask(id: "manual1", priority: 10)
    queueManager.addToQueue(manualTask)

    // Auto-download should have medium priority (5)
    let podcast = createTestPodcast(id: "pod1", autoDownloadEnabled: true)
    let episode = createTestEpisode(id: "ep1", podcastId: "pod1")

    autoDownloadService.onNewEpisodeDetected(episode: episode, podcast: podcast)

    let queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue.count, 2)

    // Manual task should be first (higher priority)
    XCTAssertEqual(queue[0].id, "manual1")
    XCTAssertEqual(queue[0].priority, 10)

    // Auto-download task should be second (lower priority)
    XCTAssertEqual(queue[1].priority, 5)
    XCTAssertTrue(queue[1].id.contains("auto_"))
  }

  @MainActor
  func testAcceptanceCriteriaReorderingChangesExecutionOrder() {
    // Acceptance Criteria: "Reordering queue changes execution order"
    let queueManager = InMemoryDownloadQueueManager()

    let task1 = createTestTask(id: "task1", priority: 1)
    let task2 = createTestTask(id: "task2", priority: 2)
    let task3 = createTestTask(id: "task3", priority: 3)

    queueManager.addToQueue(task1)
    queueManager.addToQueue(task2)
    queueManager.addToQueue(task3)

    // Initial order should be by priority (highest first)
    var queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue.map { $0.id }, ["task3", "task2", "task1"])

    // Reorder to put task1 first
    queueManager.reorderQueue(taskIds: ["task1", "task3", "task2"])

    queue = queueManager.getCurrentQueue()
    XCTAssertEqual(queue.map { $0.id }, ["task1", "task3", "task2"])
  }

  @MainActor
  func testAcceptanceCriteriaFailedTaskExposesRetryAndError() {
    // Acceptance Criteria: "Failed task exposes retry method and surfaces error"
    let queueManager = InMemoryDownloadQueueManager()

    let error = DownloadError.networkFailure("Connection timeout")
    let task = createTestTask(id: "task1", state: .failed).withError(error)

    queueManager.addToQueue(task)

    // Verify failed task surfaces error
    let failedTask = queueManager.getTask(id: "task1")
    XCTAssertEqual(failedTask?.state, .failed)
    XCTAssertEqual(failedTask?.error?.localizedDescription, error.localizedDescription)

    // Test retry method
    queueManager.retryFailedDownload(taskId: "task1")

    let retriedTask = queueManager.getTask(id: "task1")
    XCTAssertEqual(retriedTask?.state, .pending)  // State reset for retry
    XCTAssertEqual(retriedTask?.retryCount, 1)  // Retry count incremented
  }

  // MARK: - DownloadCoordinator Integration Tests

  @MainActor
  func testDownloadCoordinatorFullWorkflow() {
    let coordinator = DownloadCoordinator()
    let episode = createTestEpisode(id: "ep1", title: "Test Episode")

    // Add manual download
    coordinator.addDownload(for: episode, priority: 8)

    let queue = coordinator.getDownloadQueue()
    XCTAssertEqual(queue.count, 1)
    XCTAssertEqual(queue.first?.episodeId, "ep1")
    XCTAssertEqual(queue.first?.priority, 8)
    XCTAssertEqual(queue.first?.state, .pending)
  }

  @MainActor
  func testDownloadCoordinatorAutoDownloadConfiguration() {
    let coordinator = DownloadCoordinator()

    // Configure auto-download
    coordinator.configureAutoDownload(enabled: true, for: "pod1")
    XCTAssertTrue(coordinator.autoDownloadService.getAutoDownloadSetting(for: "pod1"))

    coordinator.configureAutoDownload(enabled: false, for: "pod1")
    XCTAssertFalse(coordinator.autoDownloadService.getAutoDownloadSetting(for: "pod1"))
  }

  @MainActor
  func testDownloadCoordinatorStoragePolicyApplication() {
    let coordinator = DownloadCoordinator()

    // Create test episodes with different dates
    let oldEpisode = createTestEpisode(
      id: "old",
      title: "Old Episode",
      pubDate: Date(timeIntervalSince1970: 100)
    )
    let newEpisode = createTestEpisode(
      id: "new",
      title: "New Episode",
      pubDate: Date(timeIntervalSince1970: 300)
    )

    // Add downloads for both episodes
    coordinator.addDownload(for: oldEpisode)
    coordinator.addDownload(for: newEpisode)

    let initialQueue = coordinator.getDownloadQueue()
    XCTAssertEqual(initialQueue.count, 2)

    // Apply keep latest policy (should remove old episode)
    let episodes = [oldEpisode, newEpisode]
    coordinator.applyStoragePolicies(
      for: "podcast", episodes: episodes, policy: .keepLatest(count: 1))

    // Note: In this test, we're verifying the coordinator can call the policy evaluator
    // The actual file deletion would be tested separately with mock file manager
  }

  // MARK: - StoragePolicyEvaluator Tests

  func testStoragePolicyKeepLatestEpisodes() {
    let policyEvaluator = StoragePolicyEvaluator()
    let policy = StoragePolicy.keepLatest(count: 2)

    let episodes = [
      createTestEpisode(id: "ep1", title: "Episode 1", pubDate: Date(timeIntervalSince1970: 100)),
      createTestEpisode(id: "ep2", title: "Episode 2", pubDate: Date(timeIntervalSince1970: 200)),
      createTestEpisode(id: "ep3", title: "Episode 3", pubDate: Date(timeIntervalSince1970: 300)),
    ]

    let actions = policyEvaluator.evaluatePolicy(policy, for: episodes)

    XCTAssertEqual(actions.count, 1)
    if case .deleteEpisode(let episodeId) = actions.first {
      XCTAssertEqual(episodeId, "ep1")  // Oldest should be marked for deletion
    } else {
      XCTFail("Expected deleteEpisode action")
    }
  }

  func testStoragePolicyDeleteOlderThan() {
    let policyEvaluator = StoragePolicyEvaluator()
    let cutoffDate = Date(timeIntervalSince1970: 200)
    let policy = StoragePolicy.deleteOlderThan(date: cutoffDate)

    let episodes = [
      createTestEpisode(id: "ep1", title: "Episode 1", pubDate: Date(timeIntervalSince1970: 100)),
      createTestEpisode(id: "ep2", title: "Episode 2", pubDate: Date(timeIntervalSince1970: 250)),
    ]

    let actions = policyEvaluator.evaluatePolicy(policy, for: episodes)

    XCTAssertEqual(actions.count, 1)
    if case .deleteEpisode(let episodeId) = actions.first {
      XCTAssertEqual(episodeId, "ep1")  // Only ep1 is older than cutoff
    } else {
      XCTFail("Expected deleteEpisode action")
    }
  }

  // MARK: - FileManagerService Tests

  @MainActor
  func testFileManagerServiceDirectoryCreation() {
    let fileManager = MockFileManagerService()
    let task = createTestTask(id: "task1", episodeId: "ep1", podcastId: "pod1")

    let expectedPath = fileManager.downloadPath(for: task)
    XCTAssertTrue(expectedPath.contains("pod1"))
    XCTAssertTrue(expectedPath.contains("ep1"))

    fileManager.createDownloadDirectory(for: task)
    XCTAssertTrue(fileManager.createdDirectories.contains { $0.contains("pod1") })
  }

  @MainActor
  func testFileManagerServiceDownloadProgress() {
    let fileManager = MockFileManagerService()
    let task = createTestTask(id: "task1", episodeId: "ep1", podcastId: "pod1")
    let expectation = XCTestExpectation(description: "Download progress")
    var progressUpdates: [Double] = []

    fileManager.downloadProgressPublisher
      .sink { progress in
        progressUpdates.append(progress.progress)
        if progress.progress >= 1.0 {
          expectation.fulfill()
        }
      }
      .store(in: &cancellables)

    fileManager.startDownload(task)

    wait(for: [expectation], timeout: 2.0)

    XCTAssertGreaterThan(progressUpdates.count, 0)
    XCTAssertEqual(progressUpdates.last!, 1.0, accuracy: 0.01)
  }

  // MARK: - Helper Methods

  private func createTestTask(
    id: String,
    episodeId: String = "defaultEpisode",
    podcastId: String = "defaultPodcast",
    state: DownloadState = .pending,
    priority: Int = 1
  ) -> DownloadTask {
    DownloadTask(
      id: id,
      episodeId: episodeId,
      podcastId: podcastId,
      state: state,
      priority: priority
    )
  }

  private func createTestPodcast(id: String, autoDownloadEnabled: Bool) -> Podcast {
    Podcast(
      id: id,
      title: "Test Podcast",
      feedURL: URL(string: "https://example.com/feed")!,
      isSubscribed: autoDownloadEnabled
    )
  }

  private func createTestEpisode(
    id: String,
    title: String = "Test Episode",
    podcastId: String = "defaultPodcast",
    pubDate: Date? = nil
  ) -> Episode {
    Episode(
      id: id,
      title: title,
      pubDate: pubDate,
      podcastId: podcastId
    )
  }
}

// MARK: - Mock Classes for Testing

class MockFileManagerService: FileManagerServicing {
  var createdDirectories: [String] = []
  var downloadedFiles: [String] = []
  private let progressSubject = PassthroughSubject<DownloadProgress, Never>()

  var downloadProgressPublisher: AnyPublisher<DownloadProgress, Never> {
    progressSubject.eraseToAnyPublisher()
  }

  func downloadPath(for task: DownloadTask) -> String {
    return "Downloads/\(task.podcastId)/\(task.episodeId).mp3"
  }

  func createDownloadDirectory(for task: DownloadTask) {
    let path = "Downloads/\(task.podcastId)/"
    createdDirectories.append(path)
  }

  func startDownload(_ task: DownloadTask) {
    createDownloadDirectory(for: task)

    // Simulate download progress
    DispatchQueue.global().async {
      for i in 1...10 {
        let progress = Double(i) / 10.0
        DispatchQueue.main.async {
          self.progressSubject.send(DownloadProgress(taskId: task.id, progress: progress))
        }
        Thread.sleep(forTimeInterval: 0.1)
      }
    }
  }

  func cancelDownload(taskId: String) {
    // Mock implementation
  }

  func deleteDownloadedFile(for task: DownloadTask) {
    let path = downloadPath(for: task)
    downloadedFiles.removeAll { $0 == path }
  }
}

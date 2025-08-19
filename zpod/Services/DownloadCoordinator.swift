@preconcurrency import Combine
import Foundation

/// Coordinates all download-related operations
@MainActor
public class DownloadCoordinator {
  public let queueManager: DownloadQueueManaging
  public let autoDownloadService: AutoDownloadService
  public let storagePolicyEvaluator: StoragePolicyEvaluator
  public let fileManagerService: FileManagerServicing
  private let autoProcessingEnabled: Bool

  private var cancellables = Set<AnyCancellable>()
  private let maxRetryCount = 3
  private let retryDelays: [TimeInterval] = [5, 15, 60]  // Exponential backoff

  public init(
    queueManager: DownloadQueueManaging? = nil,
    fileManagerService: FileManagerServicing? = nil,
    autoProcessingEnabled: Bool = false
  ) {
    self.queueManager = queueManager ?? InMemoryDownloadQueueManager()
    self.fileManagerService = fileManagerService ?? FileManagerService()
    self.storagePolicyEvaluator = StoragePolicyEvaluator()
    self.autoDownloadService = AutoDownloadService(queueManager: self.queueManager)
    self.autoProcessingEnabled = autoProcessingEnabled

    if autoProcessingEnabled {
      setupDownloadProcessing()
    }
    setupProgressTracking()
  }

  // MARK: - Public API

  /// Add manual download task
  public func addDownload(for episode: Episode, priority: Int = 5) {
    let task = DownloadTask(
      id: "manual_\(episode.id)_\(Date().timeIntervalSince1970)",
      episodeId: episode.id,
      podcastId: episode.podcastId ?? "unknown",
      state: .pending,
      priority: priority
    )
    queueManager.addToQueue(task)
  }

  /// Configure auto-download for a podcast
  public func configureAutoDownload(enabled: Bool, for podcastId: String) {
    autoDownloadService.setAutoDownload(enabled: enabled, for: podcastId)
  }

  /// Apply storage policies for cleanup
  public func applyStoragePolicies(
    for podcastId: String, episodes: [Episode], policy: StoragePolicy
  ) {
    let actions = storagePolicyEvaluator.evaluatePolicy(policy, for: episodes)
    executeStorageActions(actions)
  }

  /// Get download queue state
  public func getDownloadQueue() -> [DownloadTask] {
    return queueManager.getCurrentQueue()
  }

  // MARK: - Private Implementation

  private func setupDownloadProcessing() {
    // Monitor queue changes and process pending downloads
    queueManager.queuePublisher
      .sink { [weak self] queue in
        self?.processPendingDownloads(queue)
      }
      .store(in: &cancellables)
  }

  private func setupProgressTracking() {
    // Monitor download progress and update task states
    fileManagerService.downloadProgressPublisher
      .sink { [weak self] progress in
        self?.updateTaskProgress(progress)
      }
      .store(in: &cancellables)
  }

  private func processPendingDownloads(_ queue: [DownloadTask]) {
    // Find first pending task and start download
    guard let pendingTask = queue.first(where: { $0.state == .pending }) else { return }

    // Update state to downloading
    let updatedTask = pendingTask.withState(.downloading)
    queueManager.removeFromQueue(taskId: pendingTask.id)
    queueManager.addToQueue(updatedTask)

    // Start actual download
    fileManagerService.startDownload(updatedTask)
  }

  private func updateTaskProgress(_ progress: DownloadProgress) {
    guard var task = queueManager.getTask(id: progress.taskId) else { return }

    if progress.progress >= 1.0 {
      // Download completed
      task = task.withState(.completed).withProgress(1.0)
    } else {
      // Progress update
      task = task.withProgress(progress.progress)
    }

    queueManager.removeFromQueue(taskId: task.id)
    queueManager.addToQueue(task)

    // If completed, check for next pending download
    if task.state == .completed {
      let queue = queueManager.getCurrentQueue()
      processPendingDownloads(queue)
    }
  }

  private func handleDownloadFailure(_ task: DownloadTask, error: DownloadError) {
    let failedTask = task.withState(.failed).withError(error)
    queueManager.removeFromQueue(taskId: task.id)
    queueManager.addToQueue(failedTask)

    // Schedule retry if under retry limit
    if task.retryCount < maxRetryCount {
      scheduleRetry(for: failedTask)
    }
  }

  private func scheduleRetry(for task: DownloadTask) {
    let retryIndex = min(task.retryCount, retryDelays.count - 1)
    let delay = retryDelays[retryIndex]

    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      self?.queueManager.retryFailedDownload(taskId: task.id)
    }
  }

  private func executeStorageActions(_ actions: [StorageAction]) {
    for action in actions {
      switch action {
      case .deleteEpisode(let episodeId):
        // Find and delete download task for this episode
        if let task = queueManager.getCurrentQueue().first(where: { $0.episodeId == episodeId }) {
          fileManagerService.deleteDownloadedFile(for: task)
          queueManager.removeFromQueue(taskId: task.id)
        }

      case .archiveEpisode(let episodeId):
        // Future: Move to archive location
        print("Archive episode: \(episodeId)")
      }
    }
  }
}

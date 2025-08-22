#if canImport(Combine)
@preconcurrency import Combine
#endif
import Foundation
import CoreModels
import Persistence

/// Coordinates all download-related operations
@MainActor
public class DownloadCoordinator {
  public let queueManager: DownloadQueueManaging
  public let autoDownloadService: AutoDownloadService
  public let storagePolicyEvaluator: StoragePolicyEvaluator
  public let fileManagerService: FileManagerServicing
  private let autoProcessingEnabled: Bool

  #if canImport(Combine)
  private var cancellables = Set<AnyCancellable>()
  #endif
  private let maxRetryCount = 3
  private let retryDelays: [TimeInterval] = [5, 15, 60]  // Exponential backoff

  public init(
    queueManager: DownloadQueueManaging? = nil,
    fileManagerService: FileManagerServicing? = nil,
    autoProcessingEnabled: Bool = false
  ) {
    self.queueManager = queueManager ?? InMemoryDownloadQueueManager()
    self.fileManagerService = fileManagerService ?? DummyFileManagerService()
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
    let priorityEnum: DownloadPriority = priority <= 2 ? .low : priority >= 4 ? .high : .normal
    let task = DownloadTask(
      id: "manual_\(episode.id)_\(Date().timeIntervalSince1970)",
      episodeId: episode.id,
      podcastId: episode.id, // Episodes don't have separate podcastId in the current model
      audioURL: episode.audioURL ?? URL(string: "https://example.com/default.mp3")!,
      title: episode.title,
      estimatedSize: episode.duration.map { Int64($0 * 1024 * 1024) }, // Rough estimate
      priority: priorityEnum
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
  ) async {
    let actions = await storagePolicyEvaluator.evaluatePolicy(policy, for: episodes)
    await executeStorageActions(actions)
  }

  /// Get download queue state
  public func getDownloadQueue() -> [DownloadTask] {
    return queueManager.getCurrentQueue()
  }

  // MARK: - Private Implementation

  private func setupDownloadProcessing() {
    #if canImport(Combine)
    // Monitor queue changes and process pending downloads
    queueManager.queuePublisher
      .sink { [weak self] queue in
        Task {
          await self?.processPendingDownloads(queue)
        }
      }
      .store(in: &cancellables)
    #endif
  }

  private func setupProgressTracking() {
    #if canImport(Combine)
    // Monitor download progress and update task states
    fileManagerService.downloadProgressPublisher
      .sink { [weak self] progress in
        self?.updateTaskProgress(progress)
      }
      .store(in: &cancellables)
    #endif
  }

  private func processPendingDownloads(_ queue: [DownloadTask]) async {
    // Find first pending task and start download
    for task in queue {
      if let downloadInfo = queueManager.getTask(id: task.id), downloadInfo.state == .pending {
        // Update state to downloading
        let updatedInfo = downloadInfo.withState(.downloading)
        queueManager.removeFromQueue(taskId: task.id)
        queueManager.addToQueue(updatedInfo.task)
        
        // Start actual download
        do {
          try await fileManagerService.startDownload(updatedInfo.task)
        } catch {
          handleDownloadFailure(task, error: DownloadError.unknown(error.localizedDescription))
        }
        break
      }
    }
  }

  private func updateTaskProgress(_ progress: Persistence.DownloadProgress) {
    guard var downloadInfo = queueManager.getTask(id: progress.taskId) else { return }

    if progress.progress >= 1.0 {
      // Download completed
      downloadInfo = downloadInfo.withState(.completed)
      downloadInfo.progress = 1.0
    } else {
      // Progress update
      downloadInfo.progress = progress.progress
    }

    queueManager.removeFromQueue(taskId: downloadInfo.task.id)
    queueManager.addToQueue(downloadInfo.task)

    // If completed, check for next pending download
    if downloadInfo.state == .completed {
      let queue = queueManager.getCurrentQueue()
      Task {
        await processPendingDownloads(queue)
      }
    }
  }

  private func handleDownloadFailure(_ task: DownloadTask, error: DownloadError) {
    let failedInfo = task.withError(error)
    queueManager.removeFromQueue(taskId: task.id)
    queueManager.addToQueue(failedInfo.task)

    // Schedule retry if under retry limit
    if task.retryCount < maxRetryCount {
      scheduleRetry(for: task.withRetry())
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

  private func executeStorageActions(_ actions: [Persistence.StorageAction]) async {
    for action in actions {
      switch action {
      case .deleteEpisode(let episodeId):
        // Find and delete download task for this episode
        if let task = queueManager.getCurrentQueue().first(where: { $0.episodeId == episodeId }) {
          do {
            try await fileManagerService.deleteDownloadedFile(for: task)
          } catch {
            print("Failed to delete file for episode \(episodeId): \(error)")
          }
          queueManager.removeFromQueue(taskId: task.id)
        }

      case .archiveEpisode(let episodeId):
        // Future: Move to archive location
        print("Archive episode: \(episodeId)")
      }
    }
  }
}

/// Dummy implementation for testing/fallback
private struct DummyFileManagerService: FileManagerServicing {
  #if canImport(Combine)
  var downloadProgressPublisher: AnyPublisher<DownloadProgress, Never> {
    Empty().eraseToAnyPublisher()
  }
  #endif
  
  func downloadPath(for task: DownloadTask) async -> String {
    return "/tmp/\(task.id)"
  }
  
  func createDownloadDirectory(for task: DownloadTask) async throws {
    // No-op implementation
  }
  
  func startDownload(_ task: DownloadTask) async throws {
    // No-op implementation
  }
  
  func cancelDownload(taskId: String) async {
    // No-op implementation
  }
  
  func deleteDownloadedFile(for task: DownloadTask) async throws {
    // No-op implementation
  }
  
  func fileExists(for task: DownloadTask) async -> Bool {
    return false
  }
  
  func getFileSize(for task: DownloadTask) async -> Int64? {
    return nil
  }
}

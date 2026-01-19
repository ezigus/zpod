import CoreModels
import Foundation
import Persistence
import SharedUtilities

#if canImport(Combine)
  @preconcurrency import CombineSupport
#endif

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
    private let episodeProgressSubject = PassthroughSubject<EpisodeDownloadProgressUpdate, Never>()
    public var episodeProgressPublisher: AnyPublisher<EpisodeDownloadProgressUpdate, Never> {
      episodeProgressSubject.eraseToAnyPublisher()
    }
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
    // Start progress tracking asynchronously to access async publisher
    Task { @MainActor [weak self] in
      await self?.setupProgressTracking()
    }
  }

  // MARK: - Public API

  /// Add manual download task
  public func addDownload(for episode: Episode, priority: Int = 5) {
    let priorityEnum: DownloadPriority = priority <= 2 ? .low : priority >= 4 ? .high : .normal
    let task = DownloadTask(
      id: "manual_\(episode.id)_\(Date().timeIntervalSince1970)",
      episodeId: episode.id,
      podcastId: episode.id,  // Episodes don't have separate podcastId in the current model
      audioURL: episode.audioURL ?? URL(string: "https://example.com/default.mp3")!,
      title: episode.title,
      estimatedSize: episode.duration.map { Int64($0 * 1024 * 1024) },  // Rough estimate
      priority: priorityEnum
    )
    queueManager.addToQueue(task)
    #if canImport(Combine)
      if let info = queueManager.getTask(id: task.id) {
        emitProgress(for: info, statusOverride: .queued, message: "Queued")
      } else {
        emitProgress(forEpisodeID: episode.id, fraction: 0, status: .queued, message: "Queued")
      }
    #endif
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

  public func pauseDownload(forEpisodeID episodeID: String) {
    guard let info = downloadInfo(forEpisodeID: episodeID) else { return }
    queueManager.pauseDownload(taskId: info.task.id)
    if let updated = queueManager.getTask(id: info.task.id) {
      emitProgress(for: updated, statusOverride: .paused, message: "Paused")
    }
  }

  public func resumeDownload(forEpisodeID episodeID: String) {
    guard let info = downloadInfo(forEpisodeID: episodeID) else { return }
    queueManager.resumeDownload(taskId: info.task.id)
    if let updated = queueManager.getTask(id: info.task.id) {
      emitProgress(for: updated, statusOverride: .downloading, message: "Resumed")
    }
  }

  public func cancelDownload(forEpisodeID episodeID: String) {
    guard let info = downloadInfo(forEpisodeID: episodeID) else { return }
    queueManager.cancelDownload(taskId: info.task.id)
    if let updated = queueManager.getTask(id: info.task.id) {
      emitProgress(for: updated, statusOverride: .failed, message: "Cancelled")
    } else {
      emitProgress(forEpisodeID: episodeID, fraction: 0, status: .failed, message: "Cancelled")
    }
  }

  public func requestDownload(forEpisodeID episodeID: String) {
    guard let info = downloadInfo(forEpisodeID: episodeID) else { return }
    queueManager.retryFailedDownload(taskId: info.task.id)
    if let updated = queueManager.getTask(id: info.task.id) {
      emitProgress(for: updated, statusOverride: .queued, message: "Queued")
    }
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

  private func setupProgressTracking() async {
    #if canImport(Combine)
      // Monitor download progress and update task states
      let publisher = (await fileManagerService.downloadProgressPublisher).publisher
      publisher
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

    if let refreshed = queueManager.getTask(id: downloadInfo.task.id) {
      emitProgress(for: refreshed)
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

    if let info = queueManager.getTask(id: failedInfo.task.id) {
      emitProgress(for: info, statusOverride: .failed, message: error.localizedDescription)
    } else {
      emitProgress(
        forEpisodeID: task.episodeId, fraction: 0, status: .failed,
        message: error.localizedDescription)
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
            Logger.error("Failed to delete file for episode \(episodeId): \(error)")
          }
          queueManager.removeFromQueue(taskId: task.id)
        }

      case .archiveEpisode(let episodeId):
        // Future: Move to archive location
        Logger.info("Archive episode: \(episodeId)")
      }
    }
  }

  private func downloadInfo(forEpisodeID episodeID: String) -> DownloadInfo? {
    let tasks = queueManager.getCurrentQueue()
    guard let task = tasks.first(where: { $0.episodeId == episodeID }) else { return nil }
    return queueManager.getTask(id: task.id)
  }

  #if canImport(Combine)
    private func emitProgress(
      for info: DownloadInfo, statusOverride: EpisodeDownloadProgressStatus? = nil,
      message: String? = nil
    ) {
      let status = statusOverride ?? status(for: info.state)
      emitProgress(
        forEpisodeID: info.task.episodeId,
        fraction: info.progress,
        status: status,
        message: message
      )
    }

    private func emitProgress(
      forEpisodeID episodeID: String, fraction: Double, status: EpisodeDownloadProgressStatus,
      message: String? = nil
    ) {
      let clampedFraction = min(max(fraction, 0), 1)
      let update = EpisodeDownloadProgressUpdate(
        episodeID: episodeID,
        fractionCompleted: clampedFraction,
        status: status,
        message: message
      )
      episodeProgressSubject.send(update)
    }

    private func status(for state: DownloadState) -> EpisodeDownloadProgressStatus {
      switch state {
      case .pending:
        return .queued
      case .downloading:
        return .downloading
      case .paused:
        return .paused
      case .completed:
        return .completed
      case .failed, .cancelled:
        return .failed
      }
    }
  #endif
}

/// Dummy implementation for testing/fallback
private struct DummyFileManagerService: FileManagerServicing {
  #if canImport(Combine)
    var downloadProgressPublisher: DownloadProgressPublisher {
      get async {
        DownloadProgressPublisher(publisher: Empty<DownloadProgress, Never>().eraseToAnyPublisher())
      }
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

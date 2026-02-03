import Foundation
#if canImport(Combine)
@preconcurrency import CombineSupport
#endif
import CoreModels
import SharedUtilities

// MARK: - Download Progress Event

/// Progress or completion event emitted by `FileManagerService`.
public struct DownloadProgress: Sendable {
  public let taskId: String
  public let progress: Double
  public let state: DownloadState
  public let error: String?
  public let localFileURL: URL?

  public init(
    taskId: String,
    progress: Double,
    state: DownloadState,
    error: String? = nil,
    localFileURL: URL? = nil
  ) {
    self.taskId = taskId
    self.progress = progress
    self.state = state
    self.error = error
    self.localFileURL = localFileURL
  }
}

/// Wrapper to expose progress updates without leaking Combine details.
public struct DownloadProgressPublisher: @unchecked Sendable {
  public let publisher: AnyPublisher<DownloadProgress, Never>

  public init(publisher: AnyPublisher<DownloadProgress, Never>) {
    self.publisher = publisher
  }
}

// MARK: - Protocol

public protocol FileManagerServicing: Sendable {
  #if canImport(Combine)
  var downloadProgressPublisher: DownloadProgressPublisher { get async }
  #endif
  func downloadPath(for task: DownloadTask) async -> String
  func createDownloadDirectory(for task: DownloadTask) async throws
  func startDownload(_ task: DownloadTask) async throws
  func cancelDownload(taskId: String) async
  func deleteDownloadedFile(for task: DownloadTask) async throws
  func fileExists(for task: DownloadTask) async -> Bool
  func getFileSize(for task: DownloadTask) async -> Int64?
}

// MARK: - Implementation

/// Production file manager + downloader that drives real URLSession downloads.
public actor FileManagerService: @preconcurrency FileManagerServicing {
  private let fileManager: FileManager
  #if canImport(Combine)
    private let progressSubject = PassthroughSubject<DownloadProgress, Never>()
  #endif

  private let baseDownloadsPath: URL
  private let session: URLSession
  private let sessionDelegate: DownloadSessionDelegate

  /// Map URLSession taskIdentifier -> DownloadTask for lookup during delegate callbacks.
  private var activeTasks: [Int: DownloadTask] = [:]
  /// Map DownloadTask.id -> URLSession taskIdentifier (for cancellation).
  private var identifiersByTaskId: [String: Int] = [:]
  /// Map DownloadTask.id -> URLSessionDownloadTask for direct control (cancel/pause).
  private var downloadTasksById: [String: URLSessionDownloadTask] = [:]

  #if canImport(Combine)
    public var downloadProgressPublisher: DownloadProgressPublisher {
      get async { DownloadProgressPublisher(publisher: progressSubject.eraseToAnyPublisher()) }
    }
  #endif

  /// Create a downloader rooted at the Documents/Downloads directory by default.
  /// - Parameters:
  ///   - baseDownloadsPath: optional override for tests.
  ///   - configuration: optional URLSessionConfiguration (defaults to `.default`).
  ///   - fileManager: injected for testability.
  public init(
    baseDownloadsPath: URL? = nil,
    configuration: URLSessionConfiguration? = nil,
    fileManager: FileManager = .default
  ) throws {
    self.fileManager = fileManager

    let documents = baseDownloadsPath
      ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())

    self.baseDownloadsPath = documents.appendingPathComponent("Downloads", isDirectory: true)
    self.sessionDelegate = DownloadSessionDelegate()

    let config: URLSessionConfiguration = configuration ?? {
      let cfg = URLSessionConfiguration.default
      cfg.waitsForConnectivity = true
      cfg.allowsExpensiveNetworkAccess = true
      cfg.allowsCellularAccess = true
      return cfg
    }()

    self.session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
    self.sessionDelegate.owner = self

    if !fileManager.fileExists(atPath: self.baseDownloadsPath.path) {
      try fileManager.createDirectory(at: self.baseDownloadsPath, withIntermediateDirectories: true)
    }
  }

  // MARK: - Public API

  public func downloadPath(for task: DownloadTask) async -> String {
    let podcastDirectory = baseDownloadsPath.appendingPathComponent(task.podcastId, isDirectory: true)
    let episodeFile = podcastDirectory.appendingPathComponent("\(task.episodeId).mp3")
    return episodeFile.path
  }

  public func createDownloadDirectory(for task: DownloadTask) async throws {
    let podcastDirectory = baseDownloadsPath.appendingPathComponent(task.podcastId, isDirectory: true)
    if !fileManager.fileExists(atPath: podcastDirectory.path) {
      try fileManager.createDirectory(at: podcastDirectory, withIntermediateDirectories: true)
    }
  }

  public func startDownload(_ task: DownloadTask) async throws {
    try await createDownloadDirectory(for: task)

    // Fast path for local file URLs (used in tests and offline scenarios)
    if task.audioURL.isFileURL {
      let data = try Data(contentsOf: task.audioURL)
      let finalPath = await downloadPath(for: task)
      let finalURL = URL(fileURLWithPath: finalPath)
      let parent = finalURL.deletingLastPathComponent()
      if !fileManager.fileExists(atPath: parent.path) {
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
      }
      try data.write(to: finalURL, options: .atomic)
      #if canImport(Combine)
        progressSubject.send(
          DownloadProgress(
            taskId: task.id,
            progress: 1.0,
            state: .completed,
            localFileURL: finalURL
          )
        )
      #endif
      return
    }

    let downloadTask = session.downloadTask(with: task.audioURL)
    downloadTask.taskDescription = task.id

    activeTasks[downloadTask.taskIdentifier] = task
    identifiersByTaskId[task.id] = downloadTask.taskIdentifier
    downloadTasksById[task.id] = downloadTask

    downloadTask.resume()
  }

  public func cancelDownload(taskId: String) async {
    guard let task = downloadTasksById[taskId],
          let identifier = identifiersByTaskId[taskId]
    else { return }

    task.cancel()

    identifiersByTaskId.removeValue(forKey: taskId)
    activeTasks.removeValue(forKey: identifier)
    downloadTasksById.removeValue(forKey: taskId)

    #if canImport(Combine)
      progressSubject.send(
        DownloadProgress(
          taskId: taskId,
          progress: 0,
          state: .cancelled,
          error: DownloadError.cancelled.localizedDescription
        )
      )
    #endif
  }

  public func deleteDownloadedFile(for task: DownloadTask) async throws {
    let filePath = await downloadPath(for: task)
    let fileURL = URL(fileURLWithPath: filePath)

    if fileManager.fileExists(atPath: filePath) {
      try fileManager.removeItem(at: fileURL)
    }
  }

  public func fileExists(for task: DownloadTask) async -> Bool {
    let filePath = await downloadPath(for: task)
    return fileManager.fileExists(atPath: filePath)
  }

  public func getFileSize(for task: DownloadTask) async -> Int64? {
    let filePath = await downloadPath(for: task)
    let fileURL = URL(fileURLWithPath: filePath)

    do {
      let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
      return attributes[.size] as? Int64
    } catch {
      return nil
    }
  }

  // MARK: - Internal (delegate callbacks)

  func handleProgress(
    taskIdentifier: Int,
    bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpected: Int64
  ) async {
    guard let task = activeTasks[taskIdentifier],
          totalBytesExpected > 0
    else { return }

    let progress = Double(totalBytesWritten) / Double(totalBytesExpected)

    #if canImport(Combine)
      progressSubject.send(
        DownloadProgress(
          taskId: task.id,
          progress: progress,
          state: .downloading
        )
      )
    #endif
  }

  func handleCompletion(taskIdentifier: Int, location: URL) async {
    guard let task = activeTasks[taskIdentifier] else { return }

    defer {
      activeTasks.removeValue(forKey: taskIdentifier)
      identifiersByTaskId.removeValue(forKey: task.id)
      downloadTasksById.removeValue(forKey: task.id)
    }

    do {
      let finalPath = await downloadPath(for: task)
      let finalURL = URL(fileURLWithPath: finalPath)

      let parent = finalURL.deletingLastPathComponent()
      if !fileManager.fileExists(atPath: parent.path) {
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
      }

      if fileManager.fileExists(atPath: finalURL.path) {
        try fileManager.removeItem(at: finalURL)
      }
      try fileManager.moveItem(at: location, to: finalURL)

      #if canImport(Combine)
        progressSubject.send(
          DownloadProgress(
            taskId: task.id,
            progress: 1.0,
            state: .completed,
            localFileURL: finalURL
          )
        )
      #endif
    } catch {
      #if canImport(Combine)
        progressSubject.send(
          DownloadProgress(
            taskId: task.id,
            progress: 0,
            state: .failed,
            error: error.localizedDescription
          )
        )
      #endif
    }
  }

  func handleError(taskIdentifier: Int, error: Error?) async {
    guard let task = activeTasks[taskIdentifier] else { return }

    activeTasks.removeValue(forKey: taskIdentifier)
    identifiersByTaskId.removeValue(forKey: task.id)
    downloadTasksById.removeValue(forKey: task.id)

    let message = error?.localizedDescription
      ?? DownloadError.unknown("Download failed").localizedDescription

    #if canImport(Combine)
      progressSubject.send(
        DownloadProgress(
          taskId: task.id,
          progress: 0,
          state: .failed,
          error: message
        )
      )
    #endif
  }

}

// MARK: - Delegate Bridge

private final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
  weak var owner: FileManagerService?

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard let owner else { return }
    Task {
      await owner.handleProgress(
        taskIdentifier: downloadTask.taskIdentifier,
        bytesWritten: bytesWritten,
        totalBytesWritten: totalBytesWritten,
        totalBytesExpected: totalBytesExpectedToWrite
      )
    }
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard let owner else { return }
    Task {
      await owner.handleCompletion(taskIdentifier: downloadTask.taskIdentifier, location: location)
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let downloadTask = task as? URLSessionDownloadTask else { return }
    guard let owner else { return }
    if let error {
      Task { await owner.handleError(taskIdentifier: downloadTask.taskIdentifier, error: error) }
    }
  }
}

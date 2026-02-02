import Foundation
#if canImport(Combine)
@preconcurrency import CombineSupport
#endif
import CoreModels
import SharedUtilities

/// Progress information for downloads
public struct DownloadProgress: Sendable {
    public let taskId: String
    public let progress: Double
    
    public init(taskId: String, progress: Double) {
        self.taskId = taskId
        self.progress = progress
    }
}

/// Protocol for file management operations
public struct DownloadProgressPublisher: @unchecked Sendable {
    public let publisher: AnyPublisher<DownloadProgress, Never>

    public init(publisher: AnyPublisher<DownloadProgress, Never>) {
        self.publisher = publisher
    }
}

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

/// Implementation of file manager service for downloads
/// Uses URLSession for real download functionality
public actor FileManagerService: NSObject, @preconcurrency FileManagerServicing, URLSessionDownloadDelegate {
    private let fileManager = FileManager.default
    #if canImport(Combine)
    private let progressSubject = PassthroughSubject<DownloadProgress, Never>()
    #endif
    private let baseDownloadsPath: URL
    private var urlSession: URLSession!
    private var activeDownloads: [Int: DownloadTask] = [:] // Maps URLSessionTask.taskIdentifier -> DownloadTask

    /// Background completion handler set by AppDelegate
    public var backgroundCompletionHandler: (() -> Void)?

    #if canImport(Combine)
    public var downloadProgressPublisher: DownloadProgressPublisher {
        get async {
            DownloadProgressPublisher(publisher: progressSubject.eraseToAnyPublisher())
        }
    }
    #endif

    /// Factory method to create FileManagerService from outside the actor
    public static func create() async -> FileManagerService {
        return FileManagerService()
    }

    private override init() {
        // Must use FileManager.urls before super.init for property initialization
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback to temp directory if documents unavailable (should never happen in real app)
            self.baseDownloadsPath = FileManager.default.temporaryDirectory.appendingPathComponent("Downloads")
            super.init()
            Logger.error("Could not access Documents directory, using temp directory")
            return
        }
        self.baseDownloadsPath = documentsPath.appendingPathComponent("Downloads")

        super.init()

        // Configure background URLSession
        let configuration = URLSessionConfiguration.background(withIdentifier: "us.zig.zpod.background-downloads")
        configuration.isDiscretionary = false // Don't wait for optimal conditions
        configuration.sessionSendsLaunchEvents = true

        self.urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        // Create base directory synchronously (on init thread)
        if !fileManager.fileExists(atPath: baseDownloadsPath.path) {
            try? fileManager.createDirectory(at: baseDownloadsPath, withIntermediateDirectories: true)
        }
    }

    private func createBaseDownloadsDirectory() async {
        if !fileManager.fileExists(atPath: baseDownloadsPath.path) {
            try? fileManager.createDirectory(at: baseDownloadsPath, withIntermediateDirectories: true)
        }
    }
    
    public func downloadPath(for task: DownloadTask) async -> String {
        let podcastDirectory = baseDownloadsPath.appendingPathComponent(task.podcastId)
        let episodeFile = podcastDirectory.appendingPathComponent("\(task.episodeId).mp3")
        return episodeFile.path
    }
    
    public func createDownloadDirectory(for task: DownloadTask) async throws {
        let podcastDirectory = baseDownloadsPath.appendingPathComponent(task.podcastId)
        
        if !fileManager.fileExists(atPath: podcastDirectory.path) {
            try fileManager.createDirectory(at: podcastDirectory, withIntermediateDirectories: true)
        }
    }
    
    public func startDownload(_ task: DownloadTask) async throws {
        try await createDownloadDirectory(for: task)

        // Create URLSession download task
        let downloadTask = urlSession.downloadTask(with: task.audioURL)

        // Store task reference for progress tracking
        activeDownloads[downloadTask.taskIdentifier] = task

        // Start the download
        downloadTask.resume()

        Logger.info("Started download for episode: \(task.title) (\(task.episodeId))")
    }

    public func cancelDownload(taskId: String) async {
        // Find active download task by matching DownloadTask.id
        guard let (sessionTaskId, _) = activeDownloads.first(where: { $0.value.id == taskId }) else {
            Logger.warning("Cancel requested for unknown download task: \(taskId)")
            return
        }

        // Cancel the URLSession task
        urlSession.getAllTasks { tasks in
            if let task = tasks.first(where: { $0.taskIdentifier == sessionTaskId }) {
                task.cancel()
                Logger.info("Cancelled download task: \(taskId)")
            }
        }

        // Remove from active downloads
        activeDownloads.removeValue(forKey: sessionTaskId)
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
    
    // MARK: - URLSessionDownloadDelegate

    nonisolated public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            await self.handleDownloadCompletion(taskIdentifier: downloadTask.taskIdentifier, tempLocation: location)
        }
    }

    nonisolated public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { [weak self] in
            guard let self else { return }

            await self.handleProgressUpdate(
                taskIdentifier: downloadTask.taskIdentifier,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpectedToWrite: totalBytesExpectedToWrite
            )
        }
    }

    nonisolated public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Task { [weak self] in
            guard let self else { return }

            if let error = error {
                await self.handleDownloadError(taskIdentifier: task.taskIdentifier, error: error)
            }
        }
    }

    nonisolated public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { [weak self] in
            guard let self else { return }

            // Call background completion handler
            await self.backgroundCompletionHandler?()
        }
    }

    // MARK: - Private Delegate Handlers

    private func handleDownloadCompletion(taskIdentifier: Int, tempLocation: URL) async {
        guard let downloadTask = activeDownloads.removeValue(forKey: taskIdentifier) else {
            Logger.warning("Completed download for unknown task: \(taskIdentifier)")
            return
        }

        // Move file from temp location to final destination
        let finalPath = await downloadPath(for: downloadTask)
        let finalURL = URL(fileURLWithPath: finalPath)

        do {
            // Ensure directory exists
            let directory = finalURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            // Move file
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL) // Remove existing file
            }
            try fileManager.moveItem(at: tempLocation, to: finalURL)

            Logger.info("Download completed: \(downloadTask.title) -> \(finalPath)")

            // Emit final progress
            #if canImport(Combine)
            progressSubject.send(DownloadProgress(taskId: downloadTask.id, progress: 1.0))
            #endif

        } catch {
            Logger.error("Failed to move downloaded file: \(error.localizedDescription)")
        }
    }

    private func handleProgressUpdate(
        taskIdentifier: Int,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) async {
        guard let downloadTask = activeDownloads[taskIdentifier] else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        #if canImport(Combine)
        progressSubject.send(DownloadProgress(taskId: downloadTask.id, progress: progress))
        #endif
    }

    private func handleDownloadError(taskIdentifier: Int, error: Error) async {
        guard let downloadTask = activeDownloads.removeValue(forKey: taskIdentifier) else { return }

        Logger.error("Download failed for \(downloadTask.title): \(error.localizedDescription)")

        // TODO: Save resume data for resumable downloads
        // if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
        //     await saveResumeData(resumeData, for: downloadTask)
        // }
    }

    // MARK: - Private Methods (Removed simulation)
}

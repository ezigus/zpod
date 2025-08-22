import Foundation
#if canImport(Combine)
@preconcurrency import Combine
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
public protocol FileManagerServicing: Sendable {
    #if canImport(Combine)
    var downloadProgressPublisher: AnyPublisher<DownloadProgress, Never> { get }
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
public actor FileManagerService: FileManagerServicing {
    private let fileManager = FileManager.default
    #if canImport(Combine)
    private let progressSubject = PassthroughSubject<DownloadProgress, Never>()
    #endif
    private let baseDownloadsPath: URL
    
    #if canImport(Combine)
    public var downloadProgressPublisher: AnyPublisher<DownloadProgress, Never> {
        return progressSubject.eraseToAnyPublisher()
    }
    #endif
    
    public init() async throws {
        // Use Documents directory for downloads
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw SharedError.persistenceError("Could not access Documents directory")
        }
        baseDownloadsPath = documentsPath.appendingPathComponent("Downloads")
        await createBaseDownloadsDirectory()
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
        
        // For now, simulate download progress
        // In a real implementation, this would use URLSession to download the actual file
        await simulateDownload(for: task)
    }
    
    public func cancelDownload(taskId: String) async {
        // Stub implementation
        // In real implementation, would cancel URLSessionTask
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
    
    // MARK: - Private Methods
    
    private func simulateDownload(for task: DownloadTask) async {
        // Simulate download progress for testing purposes
        let taskId = task.id
        
        for i in 1...10 {
            let progressValue = Double(i) / 10.0
            let downloadProgress = DownloadProgress(taskId: taskId, progress: progressValue)
            
            #if canImport(Combine)
            progressSubject.send(downloadProgress)
            #endif
            
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            } catch {
                // Handle cancellation
                break
            }
        }
    }
}

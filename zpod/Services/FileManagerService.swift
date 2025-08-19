import Foundation
@preconcurrency import Combine

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
@MainActor
public protocol FileManagerServicing {
    var downloadProgressPublisher: AnyPublisher<DownloadProgress, Never> { get }
    
    func downloadPath(for task: DownloadTask) -> String
    func createDownloadDirectory(for task: DownloadTask)
    func startDownload(_ task: DownloadTask)
    func cancelDownload(taskId: String)
    func deleteDownloadedFile(for task: DownloadTask)
}

/// Implementation of file manager service for downloads
@MainActor
public class FileManagerService: FileManagerServicing {
    private let fileManager = FileManager.default
    private let progressSubject = PassthroughSubject<DownloadProgress, Never>()
    private let baseDownloadsPath: URL
    
    public var downloadProgressPublisher: AnyPublisher<DownloadProgress, Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    public init() {
        // Use Documents directory for downloads
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        baseDownloadsPath = documentsPath.appendingPathComponent("Downloads")
    }
    
    public func downloadPath(for task: DownloadTask) -> String {
        let podcastDirectory = baseDownloadsPath.appendingPathComponent(task.podcastId)
        let episodeFile = podcastDirectory.appendingPathComponent("\(task.episodeId).mp3")
        return episodeFile.path
    }
    
    public func createDownloadDirectory(for task: DownloadTask) {
        let podcastDirectory = baseDownloadsPath.appendingPathComponent(task.podcastId)
        
        do {
            try fileManager.createDirectory(at: podcastDirectory, withIntermediateDirectories: true)
        } catch let error as NSError {
            print("Failed to create download directory: \(error)")
        }
    }
    
    public func startDownload(_ task: DownloadTask) {
        createDownloadDirectory(for: task)
        
        // For now, this is a stub implementation
        // In a real implementation, this would use URLSession to download the actual file
        simulateDownload(for: task)
    }
    
    public func cancelDownload(taskId: String) {
        // Stub implementation
        // In real implementation, would cancel URLSessionTask
    }
    
    public func deleteDownloadedFile(for task: DownloadTask) {
        let filePath = downloadPath(for: task)
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch let error as NSError {
            print("Failed to delete downloaded file: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func simulateDownload(for task: DownloadTask) {
        // Simulate download progress for testing purposes
        let taskId = task.id
        
        Task {
            for i in 1...10 {
                let progressValue = Double(i) / 10.0
                let downloadProgress = DownloadProgress(taskId: taskId, progress: progressValue)
                
                await MainActor.run {
                    self.progressSubject.send(downloadProgress)
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
}

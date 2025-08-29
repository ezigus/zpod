@preconcurrency import Foundation

/// Represents a download task for an episode
public struct DownloadTask: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let episodeId: String
    public let podcastId: String
    public let audioURL: URL
    public let title: String
    public let estimatedSize: Int64?
    public let priority: DownloadPriority
    public var retryCount: Int
    
    public init(
        id: String = UUID().uuidString,
        episodeId: String,
        podcastId: String,
        audioURL: URL,
        title: String,
        estimatedSize: Int64? = nil,
        priority: DownloadPriority = .normal,
        retryCount: Int = 0
    ) {
        self.id = id
        self.episodeId = episodeId
        self.podcastId = podcastId
        self.audioURL = audioURL
        self.title = title
        self.estimatedSize = estimatedSize
        self.priority = priority
        self.retryCount = retryCount
    }
    
    /// Create a new task with updated state
    public func withState(_ state: DownloadState) -> DownloadInfo {
        return DownloadInfo(task: self, state: state)
    }
    
    /// Create a new task with updated error
    public func withError(_ error: DownloadError) -> DownloadInfo {
        return DownloadInfo(task: self, state: .failed, error: error.localizedDescription)
    }
    
    /// Create a new task with incremented retry count
    public func withRetry() -> DownloadTask {
        return DownloadTask(
            id: id,
            episodeId: episodeId,
            podcastId: podcastId,
            audioURL: audioURL,
            title: title,
            estimatedSize: estimatedSize,
            priority: priority,
            retryCount: retryCount + 1
        )
    }
}

/// Priority levels for download tasks
public enum DownloadPriority: String, Codable, CaseIterable, Sendable, Comparable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    
    public var displayName: String {
        switch self {
        case .low: return "Low Priority"
        case .normal: return "Normal Priority"
        case .high: return "High Priority"
        }
    }
    
    public static func < (lhs: DownloadPriority, rhs: DownloadPriority) -> Bool {
        switch (lhs, rhs) {
        case (.low, .normal), (.low, .high), (.normal, .high):
            return true
        default:
            return false
        }
    }
}

/// Current state of a download task
public enum DownloadState: String, Codable, Equatable, Sendable {
    case pending = "pending"
    case downloading = "downloading"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

/// Detailed information about a download including its current state
public struct DownloadInfo: Codable, Equatable, Sendable {
    public let task: DownloadTask
    public var state: DownloadState
    public var progress: Double
    public var bytesDownloaded: Int64
    public var totalBytes: Int64?
    public var error: String?
    public var downloadedAt: Date?
    
    public init(
        task: DownloadTask,
        state: DownloadState = .pending,
        progress: Double = 0.0,
        bytesDownloaded: Int64 = 0,
        totalBytes: Int64? = nil,
        error: String? = nil,
        downloadedAt: Date? = nil
    ) {
        self.task = task
        self.state = state
        self.progress = progress
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.error = error
        self.downloadedAt = downloadedAt
    }
    
    /// Create a copy with updated state
    public func withState(_ newState: DownloadState) -> DownloadInfo {
        return DownloadInfo(
            task: task,
            state: newState,
            progress: progress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            error: error,
            downloadedAt: downloadedAt
        )
    }
    
    /// Create a copy with updated error
    public func withError(_ newError: DownloadError) -> DownloadInfo {
        return DownloadInfo(
            task: task,
            state: .failed,
            progress: progress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            error: newError.localizedDescription,
            downloadedAt: downloadedAt
        )
    }
}

/// Download error types
public enum DownloadError: Error, Sendable {
    case networkUnavailable
    case invalidURL
    case fileSystemError
    case insufficientStorage
    case cancelled
    case timeout
    case authenticationFailed
    case serverError(Int)
    case unknown(String)
    
    public var localizedDescription: String {
        switch self {
        case .networkUnavailable:
            return "Network is unavailable"
        case .invalidURL:
            return "Invalid download URL"
        case .fileSystemError:
            return "File system error"
        case .insufficientStorage:
            return "Insufficient storage space"
        case .cancelled:
            return "Download was cancelled"
        case .timeout:
            return "Download timed out"
        case .authenticationFailed:
            return "Authentication failed"
        case .serverError(let code):
            return "Server error: \(code)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
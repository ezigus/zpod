import Foundation

/// Represents a download task with state, priority, and progress tracking
public struct DownloadTask: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let episodeId: String
    public let podcastId: String
    public var state: DownloadState
    public var priority: Int
    public var progress: Double
    public var retryCount: Int
    public var error: DownloadError?
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: String,
        episodeId: String,
        podcastId: String,
        state: DownloadState = .pending,
        priority: Int = 1,
        progress: Double = 0.0,
        retryCount: Int = 0,
        error: DownloadError? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.episodeId = episodeId
        self.podcastId = podcastId
        self.state = state
        self.priority = priority
        self.progress = max(0.0, min(1.0, progress))
        self.retryCount = retryCount
        self.error = error
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Create a copy of the task with updated state
    public func withState(_ newState: DownloadState) -> DownloadTask {
        DownloadTask(
            id: id,
            episodeId: episodeId,
            podcastId: podcastId,
            state: newState,
            priority: priority,
            progress: progress,
            retryCount: retryCount,
            error: error,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    /// Create a copy of the task with updated progress
    public func withProgress(_ newProgress: Double) -> DownloadTask {
        DownloadTask(
            id: id,
            episodeId: episodeId,
            podcastId: podcastId,
            state: state,
            priority: priority,
            progress: newProgress,
            retryCount: retryCount,
            error: error,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    /// Create a copy of the task with updated error
    public func withError(_ newError: DownloadError?) -> DownloadTask {
        DownloadTask(
            id: id,
            episodeId: episodeId,
            podcastId: podcastId,
            state: state,
            priority: priority,
            progress: progress,
            retryCount: retryCount,
            error: newError,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    /// Create a copy of the task with incremented retry count
    public func withIncrementedRetry() -> DownloadTask {
        DownloadTask(
            id: id,
            episodeId: episodeId,
            podcastId: podcastId,
            state: state,
            priority: priority,
            progress: progress,
            retryCount: retryCount + 1,
            error: error,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

/// Download task states
public enum DownloadState: String, Codable, CaseIterable, Sendable {
    case pending = "pending"
    case downloading = "downloading"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

/// Download error types
public enum DownloadError: Error, Codable, Equatable, Sendable {
    case networkFailure(String)
    case diskSpaceInsufficient
    case fileSystemError(String)
    case invalidURL
    case cancelled
    case unknownError(String)
    
    public var localizedDescription: String {
        switch self {
        case .networkFailure(let message):
            return "Network failure: \(message)"
        case .diskSpaceInsufficient:
            return "Insufficient disk space"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .invalidURL:
            return "Invalid download URL"
        case .cancelled:
            return "Download cancelled"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}
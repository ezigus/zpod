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
    
    public init(
        id: String = UUID().uuidString,
        episodeId: String,
        podcastId: String,
        audioURL: URL,
        title: String,
        estimatedSize: Int64? = nil,
        priority: DownloadPriority = .normal
    ) {
        self.id = id
        self.episodeId = episodeId
        self.podcastId = podcastId
        self.audioURL = audioURL
        self.title = title
        self.estimatedSize = estimatedSize
        self.priority = priority
    }
}

/// Priority levels for download tasks
public enum DownloadPriority: String, Codable, CaseIterable, Sendable {
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
}
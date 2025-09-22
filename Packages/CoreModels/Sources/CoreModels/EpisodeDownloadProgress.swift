@preconcurrency import Foundation

/// Represents granular download progress information for an episode.
public enum EpisodeDownloadProgressStatus: String, Codable, Sendable {
    case queued
    case downloading
    case paused
    case completed
    case failed
}

public struct EpisodeDownloadProgressUpdate: Codable, Sendable, Equatable {
    public let episodeID: String
    public let fractionCompleted: Double
    public let status: EpisodeDownloadProgressStatus
    public let message: String?
    
    public init(
        episodeID: String,
        fractionCompleted: Double,
        status: EpisodeDownloadProgressStatus,
        message: String? = nil
    ) {
        self.episodeID = episodeID
        self.fractionCompleted = fractionCompleted
        self.status = status
        self.message = message
    }
}

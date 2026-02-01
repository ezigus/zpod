import Foundation
import SwiftData
import CoreModels

/// SwiftData entity for persisting podcast episodes
@available(iOS 17, macOS 14, watchOS 10, *)
@Model
public final class EpisodeEntity {
    @Attribute(.unique) public var id: String
    public var podcastId: String  // Foreign key to podcast
    public var title: String
    public var podcastTitle: String
    public var episodeDescription: String?  // 'description' is reserved keyword
    public var audioURLString: String?
    public var artworkURLString: String?
    public var pubDate: Date?
    public var duration: TimeInterval?
    public var playbackPosition: Int
    public var isPlayed: Bool
    public var downloadStatus: String  // EpisodeDownloadStatus.rawValue
    public var isFavorited: Bool
    public var isBookmarked: Bool
    public var isArchived: Bool
    public var rating: Int?
    public var dateAdded: Date

    /// Whether this episode contains user-generated state that must be preserved
    public var hasUserState: Bool {
        playbackPosition > 0 ||
        isPlayed ||
        isFavorited ||
        isBookmarked ||
        downloadStatus == EpisodeDownloadStatus.downloaded.rawValue ||
        isArchived ||
        rating != nil
    }

    public init(
        id: String,
        podcastId: String,
        title: String,
        podcastTitle: String,
        episodeDescription: String? = nil,
        audioURLString: String? = nil,
        artworkURLString: String? = nil,
        pubDate: Date? = nil,
        duration: TimeInterval? = nil,
        playbackPosition: Int = 0,
        isPlayed: Bool = false,
        downloadStatus: String = "notDownloaded",
        isFavorited: Bool = false,
        isBookmarked: Bool = false,
        isArchived: Bool = false,
        rating: Int? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.podcastId = podcastId
        self.title = title
        self.podcastTitle = podcastTitle
        self.episodeDescription = episodeDescription
        self.audioURLString = audioURLString
        self.artworkURLString = artworkURLString
        self.pubDate = pubDate
        self.duration = duration
        self.playbackPosition = playbackPosition
        self.isPlayed = isPlayed
        self.downloadStatus = downloadStatus
        self.isFavorited = isFavorited
        self.isBookmarked = isBookmarked
        self.isArchived = isArchived
        self.rating = rating
        self.dateAdded = dateAdded
    }
}

// MARK: - Domain Conversion

@available(iOS 17, macOS 14, watchOS 10, *)
extension EpisodeEntity {
    /// Convert entity to domain model
    public func toDomain() -> Episode {
        Episode(
            id: id,
            title: title,
            podcastID: podcastId,
            podcastTitle: podcastTitle,
            playbackPosition: playbackPosition,
            isPlayed: isPlayed,
            pubDate: pubDate,
            duration: duration,
            description: episodeDescription,
            audioURL: audioURLString.flatMap { URL(string: $0) },
            artworkURL: artworkURLString.flatMap { URL(string: $0) },
            downloadStatus: EpisodeDownloadStatus(rawValue: downloadStatus) ?? .notDownloaded,
            isFavorited: isFavorited,
            isBookmarked: isBookmarked,
            isArchived: isArchived,
            rating: rating,
            dateAdded: dateAdded
        )
    }

    /// Create entity from domain model
    public static func fromDomain(_ episode: Episode, podcastId: String) -> EpisodeEntity {
        EpisodeEntity(
            id: episode.id,
            podcastId: podcastId,
            title: episode.title,
            podcastTitle: episode.podcastTitle,
            episodeDescription: episode.description,
            audioURLString: episode.audioURL?.absoluteString,
            artworkURLString: episode.artworkURL?.absoluteString,
            pubDate: episode.pubDate,
            duration: episode.duration,
            playbackPosition: episode.playbackPosition,
            isPlayed: episode.isPlayed,
            downloadStatus: episode.downloadStatus.rawValue,
            isFavorited: episode.isFavorited,
            isBookmarked: episode.isBookmarked,
            isArchived: episode.isArchived,
            rating: episode.rating,
            dateAdded: episode.dateAdded
        )
    }

    /// Update entity from domain model (preserves user state)
    public func updateFrom(_ episode: Episode) {
        self.title = episode.title
        self.podcastTitle = episode.podcastTitle
        self.episodeDescription = episode.description
        self.audioURLString = episode.audioURL?.absoluteString
        self.artworkURLString = episode.artworkURL?.absoluteString
        self.pubDate = episode.pubDate
        self.duration = episode.duration
        self.playbackPosition = episode.playbackPosition
        self.isPlayed = episode.isPlayed
        self.downloadStatus = episode.downloadStatus.rawValue
        self.isFavorited = episode.isFavorited
        self.isBookmarked = episode.isBookmarked
        self.isArchived = episode.isArchived
        self.rating = episode.rating
        // Note: dateAdded is NOT updated (preserves original add date)
    }

    /// Update only metadata fields, preserving user state
    public func updateMetadataFrom(_ episode: Episode) {
        self.title = episode.title
        self.podcastTitle = episode.podcastTitle
        self.episodeDescription = episode.description
        self.audioURLString = episode.audioURL?.absoluteString
        self.artworkURLString = episode.artworkURL?.absoluteString
        self.pubDate = episode.pubDate
        self.duration = episode.duration
        // Do NOT update: playbackPosition, isPlayed, downloadStatus, isFavorited,
        // isBookmarked, isArchived, rating, dateAdded
    }
}

@preconcurrency import Foundation

/// Download status for episodes
public enum EpisodeDownloadStatus: String, Codable, Sendable, CaseIterable {
    case notDownloaded
    case downloading
    case downloaded
    case failed
    
    public var displayName: String {
        switch self {
        case .notDownloaded: return "Not Downloaded"
        case .downloading: return "Downloading"
        case .downloaded: return "Downloaded"
        case .failed: return "Failed"
        }
    }
}

public struct Episode: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var podcastID: String?
    public var podcastTitle: String // Added for search and smart list functionality
    public var playbackPosition: Int
    public var isPlayed: Bool
    public var pubDate: Date?
    public var duration: TimeInterval?
    public var description: String?
    public var audioURL: URL?
    public var artworkURL: URL?
    
    // Advanced filtering properties
    public var downloadStatus: EpisodeDownloadStatus
    public var isFavorited: Bool
    public var isBookmarked: Bool
    public var isArchived: Bool
    public var rating: Int? // 1-5 star rating, nil if unrated
    public var dateAdded: Date

    public init(
        id: String, 
        title: String, 
        podcastID: String? = nil,
        podcastTitle: String = "",
        playbackPosition: Int = 0, 
        isPlayed: Bool = false,
        pubDate: Date? = nil,
        duration: TimeInterval? = nil,
        description: String? = nil,
        audioURL: URL? = nil,
        artworkURL: URL? = nil,
        downloadStatus: EpisodeDownloadStatus = .notDownloaded,
        isFavorited: Bool = false,
        isBookmarked: Bool = false,
        isArchived: Bool = false,
        rating: Int? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.podcastID = podcastID
        self.podcastTitle = podcastTitle
        self.playbackPosition = playbackPosition
        self.isPlayed = isPlayed
        self.pubDate = pubDate
        self.duration = duration
        self.description = description
        self.audioURL = audioURL
        self.artworkURL = artworkURL
        self.downloadStatus = downloadStatus
        self.isFavorited = isFavorited
        self.isBookmarked = isBookmarked
        self.isArchived = isArchived
        self.rating = rating
        self.dateAdded = dateAdded
    }

    public func withPlaybackPosition(_ position: Int) -> Episode {
        var copy = self
        copy.playbackPosition = position
        return copy
    }

    public func withPlayedStatus(_ played: Bool) -> Episode {
        var copy = self
        copy.isPlayed = played
        return copy
    }
    
    public func withDownloadStatus(_ status: EpisodeDownloadStatus) -> Episode {
        var copy = self
        copy.downloadStatus = status
        return copy
    }
    
    public func withFavoriteStatus(_ favorited: Bool) -> Episode {
        var copy = self
        copy.isFavorited = favorited
        return copy
    }
    
    public func withBookmarkStatus(_ bookmarked: Bool) -> Episode {
        var copy = self
        copy.isBookmarked = bookmarked
        return copy
    }
    
    public func withArchivedStatus(_ archived: Bool) -> Episode {
        var copy = self
        copy.isArchived = archived
        return copy
    }
    
    public func withRating(_ rating: Int?) -> Episode {
        var copy = self
        copy.rating = rating
        return copy
    }
}

// MARK: - Episode Status Helpers

public extension Episode {
    /// Whether the episode is currently in progress (started but not finished)
    var isInProgress: Bool {
        return playbackPosition > 0 && !isPlayed
    }
    
    /// Whether the episode is available for offline listening
    var isDownloaded: Bool {
        return downloadStatus == .downloaded
    }
    
    /// Whether the episode is currently being downloaded
    var isDownloading: Bool {
        return downloadStatus == .downloading
    }
    
    /// Progress of playback as a percentage (0.0 to 1.0)
    var playbackProgress: Double {
        guard let duration = duration, duration > 0 else { return 0.0 }
        return min(Double(playbackPosition) / duration, 1.0)
    }
}

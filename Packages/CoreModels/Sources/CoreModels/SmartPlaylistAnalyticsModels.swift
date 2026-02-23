import Foundation

// MARK: - SmartPlaylistPlayEvent

/// A single "play" event recorded when a user plays an episode from a smart playlist.
///
/// Events are stored in a rolling 90-day window via `SmartPlaylistAnalyticsRepository`.
/// The struct keeps its footprint small — only the fields needed for stats computation.
public struct SmartPlaylistPlayEvent: Codable, Sendable, Identifiable {
    public let id: UUID
    public let playlistID: String
    public let episodeID: String
    public let episodeDuration: TimeInterval?
    public let occurredAt: Date

    public init(
        id: UUID = UUID(),
        playlistID: String,
        episodeID: String,
        episodeDuration: TimeInterval? = nil,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.playlistID = playlistID
        self.episodeID = episodeID
        self.episodeDuration = episodeDuration
        self.occurredAt = occurredAt
    }
}

// MARK: - SmartPlaylistStats

/// Computed statistics for a single smart playlist, derived from its play event log.
public struct SmartPlaylistStats: Sendable {
    public let playlistID: String
    public let totalPlays: Int
    public let uniqueEpisodesPlayed: Int
    public let totalPlaybackDuration: TimeInterval
    public let mostRecentPlay: Date?

    public init(
        playlistID: String,
        totalPlays: Int,
        uniqueEpisodesPlayed: Int,
        totalPlaybackDuration: TimeInterval,
        mostRecentPlay: Date?
    ) {
        self.playlistID = playlistID
        self.totalPlays = totalPlays
        self.uniqueEpisodesPlayed = uniqueEpisodesPlayed
        self.totalPlaybackDuration = totalPlaybackDuration
        self.mostRecentPlay = mostRecentPlay
    }

    /// Zero-play stats for playlists with no recorded events.
    public static func empty(for playlistID: String) -> SmartPlaylistStats {
        SmartPlaylistStats(
            playlistID: playlistID,
            totalPlays: 0,
            uniqueEpisodesPlayed: 0,
            totalPlaybackDuration: 0,
            mostRecentPlay: nil
        )
    }
}

// MARK: - SmartPlaylistInsight

/// A human-readable insight derived from play-event patterns for a smart playlist.
public struct SmartPlaylistInsight: Sendable, Identifiable {
    public let id: UUID
    public let text: String
    public let systemImage: String

    public init(id: UUID = UUID(), text: String, systemImage: String) {
        self.id = id
        self.text = text
        self.systemImage = systemImage
    }
}

// MARK: - SmartPlaylistAnalyticsRepository Protocol

/// Repository for recording and querying smart playlist play events.
///
/// Lives in CoreModels so PlaylistFeature (which only depends on CoreModels) can
/// reference the protocol without a Persistence dependency. The concrete
/// `UserDefaultsSmartPlaylistAnalyticsRepository` lives in Persistence.
public protocol SmartPlaylistAnalyticsRepository: Sendable {
    func record(_ event: SmartPlaylistPlayEvent)
    func events(for playlistID: String) -> [SmartPlaylistPlayEvent]
    func stats(for playlistID: String) -> SmartPlaylistStats
    func insights(for playlistID: String) -> [SmartPlaylistInsight]
    func exportJSON(for playlistID: String) throws -> Data
    func pruneOldEvents()
}

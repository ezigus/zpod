import Foundation

// MARK: - Manual Playlist Model
public struct Playlist: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let episodeIds: [String] // Ordered episode references
    public let continuousPlayback: Bool
    public let shuffleAllowed: Bool
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        episodeIds: [String] = [],
        continuousPlayback: Bool = true,
        shuffleAllowed: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.episodeIds = episodeIds
        self.continuousPlayback = continuousPlayback
        self.shuffleAllowed = shuffleAllowed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Ensure updatedAt is strictly later than the previous value to avoid equality in fast updates
    private func nextUpdatedAt(from previous: Date) -> Date {
        let now = Date()
        if now <= previous { return previous.addingTimeInterval(0.001) }
        return now
    }
    
    public func withEpisodes(_ episodeIds: [String]) -> Playlist {
        Playlist(
            id: id,
            name: name,
            episodeIds: episodeIds,
            continuousPlayback: continuousPlayback,
            shuffleAllowed: shuffleAllowed,
            createdAt: createdAt,
            updatedAt: nextUpdatedAt(from: updatedAt)
        )
    }
    
    public func withName(_ name: String) -> Playlist {
        Playlist(
            id: id,
            name: name,
            episodeIds: episodeIds,
            continuousPlayback: continuousPlayback,
            shuffleAllowed: shuffleAllowed,
            createdAt: createdAt,
            updatedAt: nextUpdatedAt(from: updatedAt)
        )
    }
}

// MARK: - Smart Playlist Models
public enum PlaylistSortCriteria: String, Codable, CaseIterable, Sendable, Equatable {
    case pubDateNewest
    case pubDateOldest
    case titleAscending
    case titleDescending
    case durationShortest
    case durationLongest
    case playbackPosition
}

public struct PlaylistRuleData: Codable, Equatable, Sendable {
    public let type: String
    public let parameters: [String: String]
    
    public init(type: String, parameters: [String: String] = [:]) {
        self.type = type
        self.parameters = parameters
    }
}

/// Smart playlist criteria for dynamic episode selection
public struct SmartPlaylistCriteria: Codable, Equatable, Sendable {
    public let maxEpisodes: Int
    public let orderBy: SmartPlaylistOrderBy
    public let filterRules: [SmartPlaylistFilterRule]
    
    public init(
        maxEpisodes: Int = 50,
        orderBy: SmartPlaylistOrderBy = .dateAdded,
        filterRules: [SmartPlaylistFilterRule] = []
    ) {
        // Clamp to a sane range to avoid invalid values
        self.maxEpisodes = max(1, min(500, maxEpisodes))
        self.orderBy = orderBy
        self.filterRules = filterRules
    }
}

/// Order options for smart playlists
public enum SmartPlaylistOrderBy: String, Codable, Sendable {
    case dateAdded
    case publicationDate
    case duration
    case random
}

/// Filter rules for smart playlists
public enum SmartPlaylistFilterRule: Codable, Equatable, Sendable {
    case isPlayed(Bool)
    case isDownloaded // Newly added to support downloaded-based filtering
    case podcastCategory(String)
    case dateRange(start: Date, end: Date)
    case durationRange(min: TimeInterval, max: TimeInterval)
}

public struct SmartPlaylist: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let episodeIds: [String] // Current episodes matching criteria
    public let continuousPlayback: Bool
    public let shuffleAllowed: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let criteria: SmartPlaylistCriteria
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        episodeIds: [String] = [],
        continuousPlayback: Bool = true,
        shuffleAllowed: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        criteria: SmartPlaylistCriteria = SmartPlaylistCriteria()
    ) {
        self.id = id
        self.name = name
        self.episodeIds = episodeIds
        self.continuousPlayback = continuousPlayback
        self.shuffleAllowed = shuffleAllowed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.criteria = criteria
    }
    
    public func withName(_ name: String) -> SmartPlaylist {
        // Ensure updatedAt advances even under very fast successive updates
        let previous = updatedAt
        let now = Date()
        let bumped = (now <= previous) ? previous.addingTimeInterval(0.001) : now
        return SmartPlaylist(
            id: id,
            name: name,
            episodeIds: episodeIds,
            continuousPlayback: continuousPlayback,
            shuffleAllowed: shuffleAllowed,
            createdAt: createdAt,
            updatedAt: bumped,
            criteria: criteria
        )
    }
}

// Legacy SmartPlaylist for compatibility - will be removed
public struct LegacySmartPlaylist: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let rules: [PlaylistRuleData]
    public let sortCriteria: PlaylistSortCriteria
    public let continuousPlayback: Bool
    public let shuffleAllowed: Bool
    public let createdAt: Date
    public let updatedAt: Date
    public let maxEpisodes: Int
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        rules: [PlaylistRuleData] = [],
        sortCriteria: PlaylistSortCriteria = .pubDateNewest,
        continuousPlayback: Bool = true,
        shuffleAllowed: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        maxEpisodes: Int = 50
    ) {
        self.id = id
        self.name = name
        self.rules = rules
        self.sortCriteria = sortCriteria
        self.continuousPlayback = continuousPlayback
        self.shuffleAllowed = shuffleAllowed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.maxEpisodes = max(1, min(500, maxEpisodes))
    }
}

// MARK: - Rule Protocol and Implementations
public protocol PlaylistRule {
    func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool
}

public struct IsNewRule: PlaylistRule, Sendable {
    public let days: Int
    public init(days: Int) { self.days = max(1, days) }
    public func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool {
        guard let pubDate = episode.pubDate else { return false }
        let threshold = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        return pubDate >= threshold
    }
}

public struct IsDownloadedRule: PlaylistRule, Sendable {
    public init() {}
    public func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool {
        downloadStatus == .completed
    }
}

public struct IsUnplayedRule: PlaylistRule, Sendable {
    public init() {}
    public func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool {
        episode.isPlayed == false
    }
}

public struct PodcastIdRule: PlaylistRule, Sendable {
    public let podcastId: String
    public init(podcastId: String) { self.podcastId = podcastId }
    public func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool {
        episode.podcastID == podcastId
    }
}

public struct DurationRangeRule: PlaylistRule, Sendable {
    public let minSeconds: TimeInterval?
    public let maxSeconds: TimeInterval?
    public init(minSeconds: TimeInterval?, maxSeconds: TimeInterval?) {
        self.minSeconds = minSeconds
        self.maxSeconds = maxSeconds
    }
    public func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool {
        guard let duration = episode.duration else { return false }
        if let minSeconds, duration < minSeconds { return false }
        if let maxSeconds, duration > maxSeconds { return false }
        return true
    }
}

public enum PlaylistRuleFactory {
    public static func createRule(from data: PlaylistRuleData) -> (any PlaylistRule)? {
        switch data.type {
        case "isNew":
            if let s = data.parameters["days"], let d = Int(s) { return IsNewRule(days: d) }
            return nil
        case "isDownloaded":
            return IsDownloadedRule()
        case "isUnplayed":
            return IsUnplayedRule()
        case "podcastId":
            if let id = data.parameters["podcastId"], !id.isEmpty { return PodcastIdRule(podcastId: id) }
            return nil
        case "durationRange":
            let minS = data.parameters["min"].flatMap { TimeInterval($0) }
            let maxS = data.parameters["max"].flatMap { TimeInterval($0) }
            return DurationRangeRule(minSeconds: minS, maxSeconds: maxS)
        default:
            return nil
        }
    }
}

// MARK: - Change Events
public enum PlaylistChange: Sendable {
    case playlistAdded(Playlist)
    case playlistUpdated(Playlist)
    case playlistDeleted(String)
    case smartPlaylistAdded(SmartPlaylist)
    case smartPlaylistUpdated(SmartPlaylist)
    case smartPlaylistDeleted(String)
}

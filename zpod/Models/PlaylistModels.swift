import Foundation

/// Manual playlist with ordered episode references
public struct Playlist: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let episodeIds: [String]  // Ordered episode references
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
    
    /// Create a copy with updated episode list
    public func withEpisodes(_ episodeIds: [String]) -> Playlist {
        Playlist(
            id: id,
            name: name,
            episodeIds: episodeIds,
            continuousPlayback: continuousPlayback,
            shuffleAllowed: shuffleAllowed,
            createdAt: createdAt,
            updatedAt: Date().addingTimeInterval(0.001) // Add 1ms to ensure different timestamp
        )
    }
    
    /// Create a copy with updated name
    public func withName(_ name: String) -> Playlist {
        Playlist(
            id: id,
            name: name,
            episodeIds: episodeIds,
            continuousPlayback: continuousPlayback,
            shuffleAllowed: shuffleAllowed,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    /// Create a copy with updated settings
    public func withSettings(continuousPlayback: Bool? = nil, shuffleAllowed: Bool? = nil) -> Playlist {
        Playlist(
            id: id,
            name: name,
            episodeIds: episodeIds,
            continuousPlayback: continuousPlayback ?? self.continuousPlayback,
            shuffleAllowed: shuffleAllowed ?? self.shuffleAllowed,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    /// Default empty playlist
    public static let `default` = Playlist(
        name: "New Playlist",
        episodeIds: [],
        continuousPlayback: true,
        shuffleAllowed: true
    )
}

/// Smart playlist with rule-based dynamic content
public struct SmartPlaylist: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let rules: [PlaylistRuleData]  // Serializable rule configurations
    public let sortCriteria: PlaylistSortCriteria
    public let continuousPlayback: Bool
    public let shuffleAllowed: Bool
    public let createdAt: Date
    public let updatedAt: Date
    
    /// Maximum episodes to include (prevents runaway playlists)
    public let maxEpisodes: Int
    
    /// Constants for max episodes validation
    public static let minMaxEpisodes = 1
    public static let maxMaxEpisodes = 500
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        rules: [PlaylistRuleData] = [],
        sortCriteria: PlaylistSortCriteria = .pubDateNewest,
        continuousPlayback: Bool = true,
        shuffleAllowed: Bool = true,
        maxEpisodes: Int = 100,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.rules = rules
        self.sortCriteria = sortCriteria
        self.continuousPlayback = continuousPlayback
        self.shuffleAllowed = shuffleAllowed
        self.maxEpisodes = max(SmartPlaylist.minMaxEpisodes, min(SmartPlaylist.maxMaxEpisodes, maxEpisodes))  // Clamp between minMaxEpisodes-maxMaxEpisodes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Create a copy with updated rules
    public func withRules(_ rules: [PlaylistRuleData]) -> SmartPlaylist {
        SmartPlaylist(
            id: id,
            name: name,
            rules: rules,
            sortCriteria: sortCriteria,
            continuousPlayback: continuousPlayback,
            shuffleAllowed: shuffleAllowed,
            maxEpisodes: maxEpisodes,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    /// Create a copy with updated name
    public func withName(_ name: String) -> SmartPlaylist {
        SmartPlaylist(
            id: id,
            name: name,
            rules: rules,
            sortCriteria: sortCriteria,
            continuousPlayback: continuousPlayback,
            shuffleAllowed: shuffleAllowed,
            maxEpisodes: maxEpisodes,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    /// Create a copy with updated sort criteria
    public func withSortCriteria(_ sortCriteria: PlaylistSortCriteria) -> SmartPlaylist {
        SmartPlaylist(
            id: id,
            name: name,
            rules: rules,
            sortCriteria: sortCriteria,
            continuousPlayback: continuousPlayback,
            shuffleAllowed: shuffleAllowed,
            maxEpisodes: maxEpisodes,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
    
    /// Default smart playlist (all unplayed episodes)
    public static let `default` = SmartPlaylist(
        name: "New Smart Playlist",
        rules: [IsUnplayedRule().ruleData],
        sortCriteria: .pubDateNewest,
        maxEpisodes: 50
    )
}

/// Sort criteria for smart playlists
public enum PlaylistSortCriteria: String, Codable, CaseIterable, Sendable {
    case pubDateNewest = "pubDateNewest"
    case pubDateOldest = "pubDateOldest"
    case titleAscending = "titleAscending"
    case titleDescending = "titleDescending"
    case durationShortest = "durationShortest"
    case durationLongest = "durationLongest"
    case playbackPosition = "playbackPosition"  // Resume partially played first
    
    public var displayName: String {
        switch self {
        case .pubDateNewest: return "Newest First"
        case .pubDateOldest: return "Oldest First"
        case .titleAscending: return "Title A-Z"
        case .titleDescending: return "Title Z-A"
        case .durationShortest: return "Shortest First"
        case .durationLongest: return "Longest First"
        case .playbackPosition: return "Resume In Progress"
        }
    }
}

/// Codable rule data for persistence
public struct PlaylistRuleData: Codable, Equatable, Sendable {
    public let type: String
    public let parameters: [String: String]  // String-encoded parameters
    
    public init(type: String, parameters: [String: String] = [:]) {
        self.type = type
        self.parameters = parameters
    }
}

/// Protocol for playlist rule evaluation
public protocol PlaylistRule {
    /// Evaluate if an episode matches this rule
    func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool
    
    /// Serializable representation for storage
    var ruleData: PlaylistRuleData { get }
}

/// Rule for episodes published within X days
public struct IsNewRule: PlaylistRule, Sendable {
    public let daysThreshold: Int  // Episode published within X days
    
    /// Seconds in a day constant
    public static let secondsPerDay: Double = 24 * 60 * 60  // 86400 seconds
    
    public init(daysThreshold: Int = 7) {
        self.daysThreshold = max(1, daysThreshold)  // Minimum 1 day
    }
    
    public func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool {
        guard let pubDate = episode.pubDate else { return false }
        let thresholdDate = Date().addingTimeInterval(-TimeInterval(Double(daysThreshold) * IsNewRule.secondsPerDay))
        return pubDate >= thresholdDate
    }
    
    public var ruleData: PlaylistRuleData {
        PlaylistRuleData(
            type: "isNew",
            parameters: ["days": String(daysThreshold)]
        )
    }
}

/// Rule for downloaded episodes
public struct IsDownloadedRule: PlaylistRule, Sendable {
    public init() {}
    
    public func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool {
        return downloadStatus == .completed
    }
    
    public var ruleData: PlaylistRuleData {
        PlaylistRuleData(type: "isDownloaded")
    }
}

/// Rule for unplayed episodes
public struct IsUnplayedRule: PlaylistRule, Sendable {
    public let positionThreshold: TimeInterval  // <30s considered unplayed
    
    public init(positionThreshold: TimeInterval = 30.0) {
        self.positionThreshold = max(0, positionThreshold)
    }
    
    public func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool {
        return !episode.isPlayed && episode.playbackPosition < positionThreshold
    }
    
    public var ruleData: PlaylistRuleData {
        PlaylistRuleData(
            type: "isUnplayed",
            parameters: ["positionThreshold": String(positionThreshold)]
        )
    }
}

/// Rule for episodes from specific podcast
public struct PodcastIdRule: PlaylistRule {
    public let podcastId: String
    
    public init(podcastId: String) {
        self.podcastId = podcastId
    }
    
    public func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool {
        return episode.podcastId == podcastId
    }
    
    public var ruleData: PlaylistRuleData {
        PlaylistRuleData(
            type: "podcastId",
            parameters: ["podcastId": podcastId]
        )
    }
}

/// Rule for episodes within duration range
public struct DurationRangeRule: PlaylistRule, Sendable {
    public let minDuration: TimeInterval?
    public let maxDuration: TimeInterval?
    
    public init(minDuration: TimeInterval? = nil, maxDuration: TimeInterval? = nil) {
        self.minDuration = minDuration.map { max(0, $0) }
        self.maxDuration = maxDuration.map { max(0, $0) }
    }
    
    public func matches(episode: Episode, downloadStatus: DownloadState?) -> Bool {
        guard let duration = episode.duration else { return false }
        
        if let min = minDuration, duration < min { return false }
        if let max = maxDuration, duration > max { return false }
        return true
    }
    
    public var ruleData: PlaylistRuleData {
        var parameters: [String: String] = [:]
        if let min = minDuration {
            parameters["minDuration"] = String(min)
        }
        if let max = maxDuration {
            parameters["maxDuration"] = String(max)
        }
        return PlaylistRuleData(
            type: "durationRange",
            parameters: parameters
        )
    }
}

/// Factory for creating rules from serialized data
public struct PlaylistRuleFactory: Sendable {
    public static func createRule(from data: PlaylistRuleData) -> PlaylistRule? {
        switch data.type {
        case "isNew":
            let days = data.parameters["days"].flatMap(Int.init) ?? 7
            return IsNewRule(daysThreshold: days)
        case "isDownloaded":
            return IsDownloadedRule()
        case "isUnplayed":
            let threshold = data.parameters["positionThreshold"].flatMap(TimeInterval.init) ?? 30.0
            return IsUnplayedRule(positionThreshold: threshold)
        case "podcastId":
            guard let podcastId = data.parameters["podcastId"], !podcastId.isEmpty else { return nil }
            return PodcastIdRule(podcastId: podcastId)
        case "durationRange":
            let minDuration = data.parameters["minDuration"].flatMap(TimeInterval.init)
            let maxDuration = data.parameters["maxDuration"].flatMap(TimeInterval.init)
            return DurationRangeRule(minDuration: minDuration, maxDuration: maxDuration)
        default:
            return nil
        }
    }
}
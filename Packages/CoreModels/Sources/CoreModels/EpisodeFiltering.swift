import Foundation

// MARK: - Episode Filtering Models

/// Sort options for episodes
public enum EpisodeSortBy: String, Codable, Sendable, CaseIterable {
    case pubDateNewest = "pubDate_desc"
    case pubDateOldest = "pubDate_asc"
    case duration = "duration"
    case title = "title"
    case playStatus = "playStatus"
    case downloadStatus = "downloadStatus"
    case rating = "rating"
    case dateAdded = "dateAdded"
    
    public var displayName: String {
        switch self {
        case .pubDateNewest: return "Newest First"
        case .pubDateOldest: return "Oldest First"
        case .duration: return "Duration"
        case .title: return "Title"
        case .playStatus: return "Play Status"
        case .downloadStatus: return "Download Status"
        case .rating: return "Rating"
        case .dateAdded: return "Date Added"
        }
    }
}

/// Filter criteria for episodes
public enum EpisodeFilterCriteria: String, Codable, Sendable, CaseIterable {
    case unplayed
    case downloaded
    case favorited
    case inProgress
    case bookmarked
    case archived
    case rated
    case unrated
    
    public var displayName: String {
        switch self {
        case .unplayed: return "Unplayed"
        case .downloaded: return "Downloaded"
        case .favorited: return "Favorited"
        case .inProgress: return "In Progress"
        case .bookmarked: return "Bookmarked"
        case .archived: return "Archived"
        case .rated: return "Rated"
        case .unrated: return "Unrated"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .unplayed: return "circle"
        case .downloaded: return "arrow.down.circle.fill"
        case .favorited: return "heart.fill"
        case .inProgress: return "play.circle.fill"
        case .bookmarked: return "bookmark.fill"
        case .archived: return "archivebox.fill"
        case .rated: return "star.fill"
        case .unrated: return "star"
        }
    }
}

/// Logical operation for combining filters
public enum FilterLogic: String, Codable, Sendable {
    case and
    // Filter syntax intentionally mirrors boolean operators.
    // swiftlint:disable:next identifier_name
    case or
    
    public var displayName: String {
        switch self {
        case .and: return "AND"
        case .or: return "OR"
        }
    }
}

/// Individual filter condition
public struct EpisodeFilterCondition: Codable, Equatable, Sendable {
    public let criteria: EpisodeFilterCriteria
    public let isNegated: Bool // For NOT conditions
    
    public init(criteria: EpisodeFilterCriteria, isNegated: Bool = false) {
        self.criteria = criteria
        self.isNegated = isNegated
    }
    
    public var displayName: String {
        let prefix = isNegated ? "Not " : ""
        return "\(prefix)\(criteria.displayName)"
    }
}

/// Complete filter configuration
public struct EpisodeFilter: Codable, Equatable, Sendable {
    public let conditions: [EpisodeFilterCondition]
    public let logic: FilterLogic
    public let sortBy: EpisodeSortBy
    
    public init(
        conditions: [EpisodeFilterCondition] = [],
        logic: FilterLogic = .and,
        sortBy: EpisodeSortBy = .pubDateNewest
    ) {
        self.conditions = conditions
        self.logic = logic
        self.sortBy = sortBy
    }
    
    public var isEmpty: Bool {
        return conditions.isEmpty
    }
    
    public var displayName: String {
        if conditions.isEmpty {
            return "All Episodes"
        }
        let conditionNames = conditions.map { $0.displayName }
        return conditionNames.joined(separator: " \(logic.displayName) ")
    }
}

/// Saved filter preset
public struct EpisodeFilterPreset: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let filter: EpisodeFilter
    public let createdAt: Date
    public let isBuiltIn: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        filter: EpisodeFilter,
        createdAt: Date = Date(),
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.filter = filter
        self.createdAt = createdAt
        self.isBuiltIn = isBuiltIn
    }
}

/// Smart episode list configuration
public struct SmartEpisodeList: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let filter: EpisodeFilter
    public let maxEpisodes: Int?
    public let autoUpdate: Bool
    public let refreshInterval: TimeInterval // in seconds
    public let createdAt: Date
    public let lastUpdated: Date
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        filter: EpisodeFilter,
        maxEpisodes: Int? = nil,
        autoUpdate: Bool = true,
        refreshInterval: TimeInterval = 300, // 5 minutes
        createdAt: Date = Date(),
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.filter = filter
        self.maxEpisodes = maxEpisodes
        self.autoUpdate = autoUpdate
        self.refreshInterval = refreshInterval
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
    }
    
    public func withLastUpdated(_ date: Date) -> SmartEpisodeList {
        SmartEpisodeList(
            id: id,
            name: name,
            filter: filter,
            maxEpisodes: maxEpisodes,
            autoUpdate: autoUpdate,
            refreshInterval: refreshInterval,
            createdAt: createdAt,
            lastUpdated: date
        )
    }
}

// MARK: - Filter Persistence

/// Per-podcast filter preferences
public struct PodcastFilterPreferences: Codable, Equatable, Sendable {
    public let podcastId: String
    public let filter: EpisodeFilter
    public let savedAt: Date
    
    public init(podcastId: String, filter: EpisodeFilter, savedAt: Date = Date()) {
        self.podcastId = podcastId
        self.filter = filter
        self.savedAt = savedAt
    }
}

/// Global filter preferences
public struct GlobalFilterPreferences: Codable, Equatable, Sendable {
    public let defaultFilter: EpisodeFilter
    public let defaultSortBy: EpisodeSortBy
    public let savedPresets: [EpisodeFilterPreset]
    public let smartLists: [SmartEpisodeList]
    public let perPodcastPreferences: [String: EpisodeFilter] // podcastId -> filter
    
    public init(
        defaultFilter: EpisodeFilter = EpisodeFilter(),
        defaultSortBy: EpisodeSortBy = .pubDateNewest,
        savedPresets: [EpisodeFilterPreset] = [],
        smartLists: [SmartEpisodeList] = [],
        perPodcastPreferences: [String: EpisodeFilter] = [:]
    ) {
        self.defaultFilter = defaultFilter
        self.defaultSortBy = defaultSortBy
        self.savedPresets = savedPresets
        self.smartLists = smartLists
        self.perPodcastPreferences = perPodcastPreferences
    }
    
    public func filterForPodcast(_ podcastId: String) -> EpisodeFilter {
        return perPodcastPreferences[podcastId] ?? defaultFilter
    }
    
    public func withPodcastPreference(podcastId: String, filter: EpisodeFilter) -> GlobalFilterPreferences {
        var newPreferences = perPodcastPreferences
        newPreferences[podcastId] = filter
        
        return GlobalFilterPreferences(
            defaultFilter: defaultFilter,
            defaultSortBy: defaultSortBy,
            savedPresets: savedPresets,
            smartLists: smartLists,
            perPodcastPreferences: newPreferences
        )
    }
    
    public func withSmartList(_ smartList: SmartEpisodeList) -> GlobalFilterPreferences {
        var newSmartLists = smartLists.filter { $0.id != smartList.id }
        newSmartLists.append(smartList)
        
        return GlobalFilterPreferences(
            defaultFilter: defaultFilter,
            defaultSortBy: defaultSortBy,
            savedPresets: savedPresets,
            smartLists: newSmartLists,
            perPodcastPreferences: perPodcastPreferences
        )
    }
}

// MARK: - Built-in Filter Presets

public extension EpisodeFilterPreset {
    static let builtInPresets: [EpisodeFilterPreset] = [
        EpisodeFilterPreset(
            id: "unplayed",
            name: "Unplayed Episodes",
            filter: EpisodeFilter(
                conditions: [EpisodeFilterCondition(criteria: .unplayed)],
                sortBy: .pubDateNewest
            ),
            isBuiltIn: true
        ),
        EpisodeFilterPreset(
            id: "downloaded",
            name: "Downloaded Episodes",
            filter: EpisodeFilter(
                conditions: [EpisodeFilterCondition(criteria: .downloaded)],
                sortBy: .pubDateNewest
            ),
            isBuiltIn: true
        ),
        EpisodeFilterPreset(
            id: "favorites",
            name: "Favorite Episodes",
            filter: EpisodeFilter(
                conditions: [EpisodeFilterCondition(criteria: .favorited)],
                sortBy: .rating
            ),
            isBuiltIn: true
        ),
        EpisodeFilterPreset(
            id: "in-progress",
            name: "In Progress",
            filter: EpisodeFilter(
                conditions: [EpisodeFilterCondition(criteria: .inProgress)],
                sortBy: .pubDateNewest
            ),
            isBuiltIn: true
        )
    ]
}

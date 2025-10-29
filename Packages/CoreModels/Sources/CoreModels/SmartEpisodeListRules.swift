//
//  SmartEpisodeListRules.swift
//  CoreModels
//
//  Enhanced smart episode list rules with comprehensive automation support
//

import Foundation

// MARK: - Enhanced Smart List Models

/// Enhanced smart episode list with rule-based automation
public struct SmartEpisodeListV2: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let rules: SmartListRuleSet
    public let sortBy: EpisodeSortBy
    public let maxEpisodes: Int?
    public let autoUpdate: Bool
    public let refreshInterval: TimeInterval
    public let createdAt: Date
    public let lastUpdated: Date
    public let isSystemGenerated: Bool // true for built-in smart lists
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        rules: SmartListRuleSet,
        sortBy: EpisodeSortBy = .pubDateNewest,
        maxEpisodes: Int? = nil,
        autoUpdate: Bool = true,
        refreshInterval: TimeInterval = 300, // 5 minutes
        createdAt: Date = Date(),
        lastUpdated: Date = Date(),
        isSystemGenerated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.rules = rules
        self.sortBy = sortBy
        self.maxEpisodes = maxEpisodes
        self.autoUpdate = autoUpdate
        self.refreshInterval = refreshInterval
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.isSystemGenerated = isSystemGenerated
    }
    
    public func withLastUpdated(_ date: Date) -> SmartEpisodeListV2 {
        SmartEpisodeListV2(
            id: id,
            name: name,
            description: description,
            rules: rules,
            sortBy: sortBy,
            maxEpisodes: maxEpisodes,
            autoUpdate: autoUpdate,
            refreshInterval: refreshInterval,
            createdAt: createdAt,
            lastUpdated: date,
            isSystemGenerated: isSystemGenerated
        )
    }
    
    /// Check if smart list needs updating based on refresh interval
    public func needsUpdate() -> Bool {
        guard autoUpdate else { return false }
        return Date().timeIntervalSince(lastUpdated) >= refreshInterval
    }
}

// MARK: - Smart List Rule System

/// Complete rule set for smart episode list
public struct SmartListRuleSet: Codable, Equatable, Sendable {
    public let rules: [SmartListRule]
    public let logic: SmartListLogic
    
    public init(rules: [SmartListRule], logic: SmartListLogic = .and) {
        self.rules = rules
        self.logic = logic
    }
}

/// Individual smart list rule
public struct SmartListRule: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let type: SmartListRuleType
    public let comparison: SmartListComparison
    public let value: SmartListRuleValue
    public let isNegated: Bool
    
    public init(
        id: String = UUID().uuidString,
        type: SmartListRuleType,
        comparison: SmartListComparison,
        value: SmartListRuleValue,
        isNegated: Bool = false
    ) {
        self.id = id
        self.type = type
        self.comparison = comparison
        self.value = value
        self.isNegated = isNegated
    }
}

/// Logic for combining multiple rules
public enum SmartListLogic: String, Codable, CaseIterable, Sendable {
    case and = "AND"
    // Matches Smart Rules query syntax for clarity.
    // swiftlint:disable:next identifier_name
    case or = "OR"
    
    public var displayName: String {
        switch self {
        case .and: return "All conditions"
        case .or: return "Any condition"
        }
    }
}

/// Types of rules that can be applied
public enum SmartListRuleType: String, Codable, CaseIterable, Sendable {
    case playStatus = "play_status"
    case downloadStatus = "download_status"
    case dateAdded = "date_added"
    case pubDate = "pub_date"
    case duration = "duration"
    case rating = "rating"
    case podcast = "podcast"
    case title = "title"
    case description = "description"
    case isFavorited = "is_favorited"
    case isBookmarked = "is_bookmarked"
    case isArchived = "is_archived"
    case playbackPosition = "playback_position"
    
    public var displayName: String {
        switch self {
        case .playStatus: return "Play Status"
        case .downloadStatus: return "Download Status"
        case .dateAdded: return "Date Added"
        case .pubDate: return "Publication Date"
        case .duration: return "Duration"
        case .rating: return "Rating"
        case .podcast: return "Podcast"
        case .title: return "Title"
        case .description: return "Description"
        case .isFavorited: return "Favorited"
        case .isBookmarked: return "Bookmarked"
        case .isArchived: return "Archived"
        case .playbackPosition: return "Progress"
        }
    }
    
    public var availableComparisons: [SmartListComparison] {
        switch self {
        case .playStatus, .downloadStatus, .isFavorited, .isBookmarked, .isArchived:
            return [.equals, .notEquals]
        case .dateAdded, .pubDate:
            return [.equals, .notEquals, .before, .after, .between, .within]
        case .duration, .rating, .playbackPosition:
            return [.equals, .notEquals, .lessThan, .greaterThan, .between]
        case .podcast, .title, .description:
            return [.contains, .notContains, .startsWith, .endsWith, .equals, .notEquals]
        }
    }
}

/// Comparison operators for rules
public enum SmartListComparison: String, Codable, CaseIterable, Sendable {
    case equals = "equals"
    case notEquals = "not_equals"
    case contains = "contains"
    case notContains = "not_contains"
    case startsWith = "starts_with"
    case endsWith = "ends_with"
    case lessThan = "less_than"
    case greaterThan = "greater_than"
    case between = "between"
    case before = "before"
    case after = "after"
    case within = "within"
    
    public var displayName: String {
        switch self {
        case .equals: return "is"
        case .notEquals: return "is not"
        case .contains: return "contains"
        case .notContains: return "does not contain"
        case .startsWith: return "starts with"
        case .endsWith: return "ends with"
        case .lessThan: return "is less than"
        case .greaterThan: return "is greater than"
        case .between: return "is between"
        case .before: return "is before"
        case .after: return "is after"
        case .within: return "is within"
        }
    }
}

/// Value types for smart list rules
public enum SmartListRuleValue: Codable, Equatable, Sendable {
    case boolean(Bool)
    case integer(Int)
    case double(Double)
    case string(String)
    case date(Date)
    case dateRange(start: Date, end: Date)
    case timeInterval(TimeInterval)
    case relativeDate(RelativeDatePeriod)
    case episodeStatus(EpisodePlayStatus)
    case downloadStatus(EpisodeDownloadStatus)
    
    public var displayValue: String {
        switch self {
        case .boolean(let value):
            return value ? "Yes" : "No"
        case .integer(let value):
            return "\(value)"
        case .double(let value):
            return String(format: "%.1f", value)
        case .string(let value):
            return value
        case .date(let value):
            return DateFormatter.localizedString(from: value, dateStyle: .medium, timeStyle: .none)
        case .dateRange(let start, let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .timeInterval(let value):
            return formatDuration(value)
        case .relativeDate(let period):
            return period.displayName
        case .episodeStatus(let status):
            return status.displayName
        case .downloadStatus(let status):
            return status.displayName
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        // Use TimeInterval extension for cross-platform compatibility
        return duration.abbreviatedDescription(includeSeconds: true)
    }
}

/// Relative date periods for smart lists
public enum RelativeDatePeriod: String, Codable, CaseIterable, Sendable {
    case today = "today"
    case yesterday = "yesterday"
    case thisWeek = "this_week"
    case lastWeek = "last_week"
    case thisMonth = "this_month"
    case lastMonth = "last_month"
    case thisYear = "this_year"
    case lastYear = "last_year"
    case last24Hours = "last_24_hours"
    case last7Days = "last_7_days"
    case last30Days = "last_30_days"
    case last90Days = "last_90_days"
    
    public var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        case .thisYear: return "This Year"
        case .lastYear: return "Last Year"
        case .last24Hours: return "Last 24 Hours"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        }
    }
    
    public func dateRange() -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)
        case .yesterday:
            let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
            let end = calendar.startOfDay(for: now)
            return (start, end)
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let end = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            return (start, end)
        case .lastWeek:
            let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? now
            let end = thisWeekStart
            return (start, end)
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let end = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return (start, end)
        case .lastMonth:
            let thisMonthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
            let end = thisMonthStart
            return (start, end)
        case .thisYear:
            let start = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let end = calendar.dateInterval(of: .year, for: now)?.end ?? now
            return (start, end)
        case .lastYear:
            let thisYearStart = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let start = calendar.date(byAdding: .year, value: -1, to: thisYearStart) ?? now
            let end = thisYearStart
            return (start, end)
        case .last24Hours:
            let start = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
            return (start, now)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start, now)
        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return (start, now)
        }
    }
}

/// Episode play status for rules
public enum EpisodePlayStatus: String, Codable, CaseIterable, Sendable {
    case unplayed = "unplayed"
    case inProgress = "in_progress"
    case played = "played"
    
    public var displayName: String {
        switch self {
        case .unplayed: return "Unplayed"
        case .inProgress: return "In Progress"
        case .played: return "Played"
        }
    }
}

// MARK: - Built-in Smart Lists

public extension SmartEpisodeListV2 {
    
    /// Built-in smart lists for common use cases
    static let builtInSmartLists: [SmartEpisodeListV2] = [
        // Recent unplayed episodes
        SmartEpisodeListV2(
            id: "recent_unplayed",
            name: "Recent Unplayed",
            description: "Unplayed episodes from the last 7 days",
            rules: SmartListRuleSet(rules: [
                SmartListRule(
                    type: .playStatus,
                    comparison: .equals,
                    value: .episodeStatus(.unplayed)
                ),
                SmartListRule(
                    type: .pubDate,
                    comparison: .within,
                    value: .relativeDate(.last7Days)
                )
            ], logic: .and),
            sortBy: .pubDateNewest,
            maxEpisodes: 50,
            isSystemGenerated: true
        ),
        
        // Downloaded interviews
        SmartEpisodeListV2(
            id: "downloaded_interviews",
            name: "Downloaded Interviews",
            description: "Downloaded episodes with 'interview' in the title",
            rules: SmartListRuleSet(rules: [
                SmartListRule(
                    type: .downloadStatus,
                    comparison: .equals,
                    value: .downloadStatus(.downloaded)
                ),
                SmartListRule(
                    type: .title,
                    comparison: .contains,
                    value: .string("interview")
                )
            ], logic: .and),
            sortBy: .pubDateNewest,
            isSystemGenerated: true
        ),
        
        // Long unplayed episodes
        SmartEpisodeListV2(
            id: "long_unplayed",
            name: "Long Unplayed Episodes",
            description: "Unplayed episodes longer than 60 minutes",
            rules: SmartListRuleSet(rules: [
                SmartListRule(
                    type: .playStatus,
                    comparison: .equals,
                    value: .episodeStatus(.unplayed)
                ),
                SmartListRule(
                    type: .duration,
                    comparison: .greaterThan,
                    value: .timeInterval(3600) // 60 minutes
                )
            ], logic: .and),
            sortBy: .duration,
            maxEpisodes: 30,
            isSystemGenerated: true
        ),
        
        // Quick episodes
        SmartEpisodeListV2(
            id: "quick_episodes",
            name: "Quick Episodes",
            description: "Unplayed episodes under 20 minutes",
            rules: SmartListRuleSet(rules: [
                SmartListRule(
                    type: .playStatus,
                    comparison: .equals,
                    value: .episodeStatus(.unplayed)
                ),
                SmartListRule(
                    type: .duration,
                    comparison: .lessThan,
                    value: .timeInterval(1200) // 20 minutes
                )
            ], logic: .and),
            sortBy: .duration,
            maxEpisodes: 25,
            isSystemGenerated: true
        ),
        
        // Highly rated episodes
        SmartEpisodeListV2(
            id: "highly_rated",
            name: "Highly Rated",
            description: "Episodes rated 4 stars or higher",
            rules: SmartListRuleSet(rules: [
                SmartListRule(
                    type: .rating,
                    comparison: .greaterThan,
                    value: .integer(3)
                )
            ], logic: .and),
            sortBy: .rating,
            maxEpisodes: 50,
            isSystemGenerated: true
        ),
        
        // In-progress episodes
        SmartEpisodeListV2(
            id: "in_progress",
            name: "Continue Listening",
            description: "Episodes that are partially played",
            rules: SmartListRuleSet(rules: [
                SmartListRule(
                    type: .playStatus,
                    comparison: .equals,
                    value: .episodeStatus(.inProgress)
                )
            ], logic: .and),
            sortBy: .dateAdded,
            maxEpisodes: 20,
            isSystemGenerated: true
        )
    ]
}

// MARK: - Smart List Rule Templates

public struct SmartListRuleTemplate: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let rules: SmartListRuleSet
    public let category: SmartListTemplateCategory
    
    public init(id: String = UUID().uuidString, name: String, description: String, rules: SmartListRuleSet, category: SmartListTemplateCategory) {
        self.id = id
        self.name = name
        self.description = description
        self.rules = rules
        self.category = category
    }
}

public enum SmartListTemplateCategory: String, Codable, CaseIterable, Sendable {
    case recent
    case duration
    case status
    case rating
    case content
    case podcast
    
    public var displayName: String {
        switch self {
        case .recent: return "Recent"
        case .duration: return "Duration"
        case .status: return "Play Status"
        case .rating: return "Rating"
        case .content: return "Content"
        case .podcast: return "Podcast"
        }
    }
}

public extension SmartListRuleTemplate {
    
    /// Common rule templates for quick smart list creation
    static let builtInTemplates: [SmartListRuleTemplate] = [
        // Recent templates
        SmartListRuleTemplate(
            name: "Today's Episodes",
            description: "Episodes published today",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .pubDate, comparison: .within, value: .relativeDate(.today))
            ]),
            category: .recent
        ),
        
        SmartListRuleTemplate(
            name: "This Week's Episodes",
            description: "Episodes published this week",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .pubDate, comparison: .within, value: .relativeDate(.thisWeek))
            ]),
            category: .recent
        ),
        
        // Duration templates
        SmartListRuleTemplate(
            name: "Short Episodes",
            description: "Episodes under 15 minutes",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .duration, comparison: .lessThan, value: .timeInterval(900))
            ]),
            category: .duration
        ),
        
        SmartListRuleTemplate(
            name: "Long Episodes",
            description: "Episodes over 90 minutes",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(5400))
            ]),
            category: .duration
        ),
        
        // Status templates
        SmartListRuleTemplate(
            name: "Downloaded Unplayed",
            description: "Downloaded episodes that haven't been played",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .downloadStatus, comparison: .equals, value: .downloadStatus(.downloaded)),
                SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
            ], logic: .and),
            category: .status
        ),
        
        // Content templates
        SmartListRuleTemplate(
            name: "News Episodes",
            description: "Episodes with 'news' in the title",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .title, comparison: .contains, value: .string("news"))
            ]),
            category: .content
        ),
        
        SmartListRuleTemplate(
            name: "Interview Episodes",
            description: "Episodes with 'interview' in the title or description",
            rules: SmartListRuleSet(rules: [
                SmartListRule(type: .title, comparison: .contains, value: .string("interview")),
                SmartListRule(type: .description, comparison: .contains, value: .string("interview"))
            ], logic: .or),
            category: .content
        )
    ]
}

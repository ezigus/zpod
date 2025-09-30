import Foundation

// MARK: - Automatic Archiving Rules

/// Conditions that trigger automatic archiving of episodes
public enum AutoArchiveCondition: String, Codable, Sendable, CaseIterable {
    case playedAndOlderThanDays = "played_and_older_than_days"
    case playedRegardlessOfAge = "played_regardless_of_age"
    case olderThanDays = "older_than_days"
    case downloadedAndPlayed = "downloaded_and_played"
    
    public var displayName: String {
        switch self {
        case .playedAndOlderThanDays: return "Played and Older Than"
        case .playedRegardlessOfAge: return "All Played Episodes"
        case .olderThanDays: return "Older Than"
        case .downloadedAndPlayed: return "Downloaded and Played"
        }
    }
    
    public var requiresDaysParameter: Bool {
        switch self {
        case .playedAndOlderThanDays, .olderThanDays:
            return true
        case .playedRegardlessOfAge, .downloadedAndPlayed:
            return false
        }
    }
}

/// Configuration for automatic episode archiving
public struct AutoArchiveRule: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let isEnabled: Bool
    public let condition: AutoArchiveCondition
    public let daysOld: Int? // Required for conditions that need age parameter
    public let excludeFavorites: Bool // Don't auto-archive favorited episodes
    public let excludeBookmarked: Bool // Don't auto-archive bookmarked episodes
    public let createdAt: Date
    public let lastAppliedAt: Date?
    
    public init(
        id: String = UUID().uuidString,
        isEnabled: Bool = true,
        condition: AutoArchiveCondition,
        daysOld: Int? = nil,
        excludeFavorites: Bool = true,
        excludeBookmarked: Bool = true,
        createdAt: Date = Date(),
        lastAppliedAt: Date? = nil
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.condition = condition
        self.daysOld = daysOld
        self.excludeFavorites = excludeFavorites
        self.excludeBookmarked = excludeBookmarked
        self.createdAt = createdAt
        self.lastAppliedAt = lastAppliedAt
    }
    
    /// Validate that the rule is properly configured
    public var isValid: Bool {
        if condition.requiresDaysParameter {
            guard let days = daysOld, days > 0 else {
                return false
            }
        }
        return true
    }
    
    /// Human-readable description of the rule
    public var description: String {
        var parts: [String] = []
        
        switch condition {
        case .playedAndOlderThanDays:
            if let days = daysOld {
                parts.append("Archive played episodes older than \(days) days")
            }
        case .playedRegardlessOfAge:
            parts.append("Archive all played episodes")
        case .olderThanDays:
            if let days = daysOld {
                parts.append("Archive episodes older than \(days) days")
            }
        case .downloadedAndPlayed:
            parts.append("Archive downloaded and played episodes")
        }
        
        if excludeFavorites {
            parts.append("(except favorites)")
        }
        if excludeBookmarked {
            parts.append("(except bookmarked)")
        }
        
        return parts.joined(separator: " ")
    }
    
    public func withLastApplied(_ date: Date) -> AutoArchiveRule {
        AutoArchiveRule(
            id: id,
            isEnabled: isEnabled,
            condition: condition,
            daysOld: daysOld,
            excludeFavorites: excludeFavorites,
            excludeBookmarked: excludeBookmarked,
            createdAt: createdAt,
            lastAppliedAt: date
        )
    }
    
    public func withEnabled(_ enabled: Bool) -> AutoArchiveRule {
        AutoArchiveRule(
            id: id,
            isEnabled: enabled,
            condition: condition,
            daysOld: daysOld,
            excludeFavorites: excludeFavorites,
            excludeBookmarked: excludeBookmarked,
            createdAt: createdAt,
            lastAppliedAt: lastAppliedAt
        )
    }
}

/// Per-podcast auto-archive configuration
public struct PodcastAutoArchiveConfig: Codable, Equatable, Sendable {
    public let podcastId: String
    public let rules: [AutoArchiveRule]
    public let isEnabled: Bool // Master switch for this podcast
    public let updatedAt: Date
    
    public init(
        podcastId: String,
        rules: [AutoArchiveRule] = [],
        isEnabled: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.podcastId = podcastId
        self.rules = rules
        self.isEnabled = isEnabled
        self.updatedAt = updatedAt
    }
    
    public func withRules(_ newRules: [AutoArchiveRule]) -> PodcastAutoArchiveConfig {
        PodcastAutoArchiveConfig(
            podcastId: podcastId,
            rules: newRules,
            isEnabled: isEnabled,
            updatedAt: Date()
        )
    }
    
    public func withEnabled(_ enabled: Bool) -> PodcastAutoArchiveConfig {
        PodcastAutoArchiveConfig(
            podcastId: podcastId,
            rules: rules,
            isEnabled: enabled,
            updatedAt: Date()
        )
    }
}

/// Global auto-archive configuration
public struct GlobalAutoArchiveConfig: Codable, Equatable, Sendable {
    public let globalRules: [AutoArchiveRule] // Applied to all podcasts by default
    public let perPodcastConfigs: [String: PodcastAutoArchiveConfig] // Podcast-specific overrides
    public let isGlobalEnabled: Bool // Master switch for all auto-archiving
    public let autoRunInterval: TimeInterval // How often to run auto-archive (in seconds)
    public let lastRunAt: Date?
    
    public init(
        globalRules: [AutoArchiveRule] = [],
        perPodcastConfigs: [String: PodcastAutoArchiveConfig] = [:],
        isGlobalEnabled: Bool = false,
        autoRunInterval: TimeInterval = 86400, // Default: once per day
        lastRunAt: Date? = nil
    ) {
        self.globalRules = globalRules
        self.perPodcastConfigs = perPodcastConfigs
        self.isGlobalEnabled = isGlobalEnabled
        self.autoRunInterval = autoRunInterval
        self.lastRunAt = lastRunAt
    }
    
    public func configForPodcast(_ podcastId: String) -> PodcastAutoArchiveConfig {
        return perPodcastConfigs[podcastId] ?? PodcastAutoArchiveConfig(podcastId: podcastId)
    }
    
    public func withPodcastConfig(_ config: PodcastAutoArchiveConfig) -> GlobalAutoArchiveConfig {
        var newConfigs = perPodcastConfigs
        newConfigs[config.podcastId] = config
        
        return GlobalAutoArchiveConfig(
            globalRules: globalRules,
            perPodcastConfigs: newConfigs,
            isGlobalEnabled: isGlobalEnabled,
            autoRunInterval: autoRunInterval,
            lastRunAt: lastRunAt
        )
    }
    
    public func withGlobalRules(_ rules: [AutoArchiveRule]) -> GlobalAutoArchiveConfig {
        GlobalAutoArchiveConfig(
            globalRules: rules,
            perPodcastConfigs: perPodcastConfigs,
            isGlobalEnabled: isGlobalEnabled,
            autoRunInterval: autoRunInterval,
            lastRunAt: lastRunAt
        )
    }
    
    public func withLastRun(_ date: Date) -> GlobalAutoArchiveConfig {
        GlobalAutoArchiveConfig(
            globalRules: globalRules,
            perPodcastConfigs: perPodcastConfigs,
            isGlobalEnabled: isGlobalEnabled,
            autoRunInterval: autoRunInterval,
            lastRunAt: date
        )
    }
    
    public func withGlobalEnabled(_ enabled: Bool) -> GlobalAutoArchiveConfig {
        GlobalAutoArchiveConfig(
            globalRules: globalRules,
            perPodcastConfigs: perPodcastConfigs,
            isGlobalEnabled: enabled,
            autoRunInterval: autoRunInterval,
            lastRunAt: lastRunAt
        )
    }
}

// MARK: - Predefined Rules

public extension AutoArchiveRule {
    /// Archive played episodes older than 30 days (common use case)
    static var playedOlderThan30Days: AutoArchiveRule {
        AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: 30,
            excludeFavorites: true,
            excludeBookmarked: true
        )
    }
    
    /// Archive all played episodes immediately (aggressive cleanup)
    static var allPlayedImmediately: AutoArchiveRule {
        AutoArchiveRule(
            condition: .playedRegardlessOfAge,
            excludeFavorites: true,
            excludeBookmarked: true
        )
    }
    
    /// Archive episodes older than 90 days regardless of play status
    static var olderThan90Days: AutoArchiveRule {
        AutoArchiveRule(
            condition: .olderThanDays,
            daysOld: 90,
            excludeFavorites: true,
            excludeBookmarked: true
        )
    }
    
    /// Archive downloaded episodes after they're played
    static var downloadedAndPlayed: AutoArchiveRule {
        AutoArchiveRule(
            condition: .downloadedAndPlayed,
            excludeFavorites: true,
            excludeBookmarked: true
        )
    }
}

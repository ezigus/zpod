import Foundation

// MARK: - Auto Archive Service

/// Service for evaluating and applying automatic archiving rules
public protocol AutoArchiveService: Sendable {
    /// Evaluate if an episode should be archived based on the given rule
    func shouldArchive(_ episode: Episode, basedOn rule: AutoArchiveRule) -> Bool
    
    /// Apply auto-archive rules to a list of episodes, returning IDs of episodes to archive
    func evaluateRules(_ rules: [AutoArchiveRule], forEpisodes episodes: [Episode]) -> [String]
    
    /// Apply auto-archive configuration for a specific podcast
    func evaluateForPodcast(
        _ config: PodcastAutoArchiveConfig,
        episodes: [Episode]
    ) -> [String]
    
    /// Check if auto-archive should run based on last run time and interval
    func shouldRunAutoArchive(_ config: GlobalAutoArchiveConfig) -> Bool
}

// MARK: - Default Implementation

public actor DefaultAutoArchiveService: AutoArchiveService {
    
    public init() {}
    
    public nonisolated func shouldArchive(_ episode: Episode, basedOn rule: AutoArchiveRule) -> Bool {
        // Don't archive if rule is disabled or invalid
        guard rule.isEnabled && rule.isValid else {
            return false
        }
        
        // Don't archive if already archived
        guard !episode.isArchived else {
            return false
        }
        
        // Check exclusions
        if rule.excludeFavorites && episode.isFavorited {
            return false
        }
        
        if rule.excludeBookmarked && episode.isBookmarked {
            return false
        }
        
        // Evaluate condition
        return evaluateCondition(rule.condition, for: episode, daysOld: rule.daysOld)
    }
    
    public nonisolated func evaluateRules(
        _ rules: [AutoArchiveRule],
        forEpisodes episodes: [Episode]
    ) -> [String] {
        var episodesToArchive = Set<String>()
        
        for rule in rules where rule.isEnabled && rule.isValid {
            for episode in episodes {
                if shouldArchive(episode, basedOn: rule) {
                    episodesToArchive.insert(episode.id)
                }
            }
        }
        
        return Array(episodesToArchive)
    }
    
    public nonisolated func evaluateForPodcast(
        _ config: PodcastAutoArchiveConfig,
        episodes: [Episode]
    ) -> [String] {
        guard config.isEnabled else {
            return []
        }
        
        return evaluateRules(config.rules, forEpisodes: episodes)
    }
    
    public nonisolated func shouldRunAutoArchive(_ config: GlobalAutoArchiveConfig) -> Bool {
        guard config.isGlobalEnabled else {
            return false
        }
        
        guard let lastRun = config.lastRunAt else {
            // Never run before, should run now
            return true
        }
        
        let timeSinceLastRun = Date().timeIntervalSince(lastRun)
        return timeSinceLastRun >= config.autoRunInterval
    }
    
    // MARK: - Private Helpers
    
    private nonisolated func evaluateCondition(
        _ condition: AutoArchiveCondition,
        for episode: Episode,
        daysOld: Int?
    ) -> Bool {
        switch condition {
        case .playedAndOlderThanDays:
            guard let days = daysOld, let pubDate = episode.pubDate else {
                return false
            }
            let daysAgo = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            return episode.isPlayed && pubDate < daysAgo
            
        case .playedRegardlessOfAge:
            return episode.isPlayed
            
        case .olderThanDays:
            guard let days = daysOld, let pubDate = episode.pubDate else {
                return false
            }
            let daysAgo = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            return pubDate < daysAgo
            
        case .downloadedAndPlayed:
            return episode.isDownloaded && episode.isPlayed
        }
    }
}

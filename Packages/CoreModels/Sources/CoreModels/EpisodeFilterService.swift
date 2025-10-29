import Foundation
import SharedUtilities

// MARK: - Episode Filtering Protocol

/// Protocol for episode filtering services
public protocol EpisodeFilterService: Sendable {
    /// Apply filter and sort to episodes
    func filterAndSort(episodes: [Episode], using filter: EpisodeFilter) -> [Episode]
    
    /// Check if episode matches filter condition
    func episodeMatches(_ episode: Episode, condition: EpisodeFilterCondition) -> Bool
    
    /// Sort episodes by criteria
    func sortEpisodes(_ episodes: [Episode], by sortBy: EpisodeSortBy) -> [Episode]
    
    /// Search episodes by text query
    func searchEpisodes(_ episodes: [Episode], query: String, filter: EpisodeFilter?, includeArchived: Bool) -> [Episode]
    
    /// Advanced search with result highlighting and context
    func searchEpisodesAdvanced(_ episodes: [Episode], query: EpisodeSearchQuery, filter: EpisodeFilter?, includeArchived: Bool) -> [EpisodeSearchResult]
    
    /// Evaluate smart list with enhanced rules
    func evaluateSmartListV2(_ smartList: SmartEpisodeListV2, allEpisodes: [Episode]) -> [Episode]
    
    /// Check if smart list needs updating based on refresh interval
    func smartListNeedsUpdateV2(_ smartList: SmartEpisodeListV2) -> Bool
    
    /// Update smart list with new episodes
    func updateSmartList(_ smartList: SmartEpisodeList, allEpisodes: [Episode]) -> [Episode]
    
    /// Check if smart list needs updating based on refresh interval
    func smartListNeedsUpdate(_ smartList: SmartEpisodeList) -> Bool
}

// MARK: - Default Implementation

/// Default implementation using composable helper services.
/// Delegates to specialized helpers for filtering, sorting, searching, and smart list evaluation.
public actor DefaultEpisodeFilterService: EpisodeFilterService {
    
    // MARK: - Helper Services
    
    private let filterEvaluator = EpisodeFilterEvaluator()
    private let sortService = EpisodeSortService()
    private let searchHelper = EpisodeSearchHelper()
    private let advancedSearchEvaluator = AdvancedSearchEvaluator()
    private let smartListRuleEvaluator = SmartListRuleEvaluator()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public API
    
    nonisolated public func filterAndSort(episodes: [Episode], using filter: EpisodeFilter) -> [Episode] {
        let filteredEpisodes = filterEvaluator.applyFilter(episodes, filter: filter)
        return sortService.sortEpisodes(filteredEpisodes, by: filter.sortBy)
    }
    
    nonisolated public func episodeMatches(_ episode: Episode, condition: EpisodeFilterCondition) -> Bool {
        return filterEvaluator.episodeMatches(episode, condition: condition)
    }
    
    nonisolated public func sortEpisodes(_ episodes: [Episode], by sortBy: EpisodeSortBy) -> [Episode] {
        return sortService.sortEpisodes(episodes, by: sortBy)
    }
    
    /// Search episodes by text query
    nonisolated public func searchEpisodes(
        _ episodes: [Episode],
        query: String,
        filter: EpisodeFilter? = nil,
        includeArchived: Bool = false
    ) -> [Episode] {
        return searchHelper.searchEpisodes(
            episodes,
            query: query,
            filter: filter,
            includeArchived: includeArchived,
            filterEvaluator: filterEvaluator,
            sortService: sortService
        )
    }
    
    /// Advanced search with result highlighting and context
    nonisolated public func searchEpisodesAdvanced(
        _ episodes: [Episode],
        query: EpisodeSearchQuery,
        filter: EpisodeFilter? = nil,
        includeArchived: Bool = false
    ) -> [EpisodeSearchResult] {
        return advancedSearchEvaluator.searchEpisodesAdvanced(
            episodes,
            query: query,
            filter: filter,
            includeArchived: includeArchived,
            filterEvaluator: filterEvaluator,
            sortService: sortService
        )
    }
    
    /// Update smart list with new episodes
    nonisolated public func updateSmartList(
        _ smartList: SmartEpisodeList,
        allEpisodes: [Episode]
    ) -> [Episode] {
        var filteredEpisodes = filterAndSort(episodes: allEpisodes, using: smartList.filter)
        
        // Apply max episode limit if specified
        if let maxEpisodes = smartList.maxEpisodes, filteredEpisodes.count > maxEpisodes {
            filteredEpisodes = Array(filteredEpisodes.prefix(maxEpisodes))
        }
        
        return filteredEpisodes
    }
    
    /// Check if smart list needs updating based on refresh interval
    nonisolated public func smartListNeedsUpdate(_ smartList: SmartEpisodeList) -> Bool {
        guard smartList.autoUpdate else { return false }
        
        let timeSinceUpdate = Date().timeIntervalSince(smartList.lastUpdated)
        return timeSinceUpdate >= smartList.refreshInterval
    }
    
    // MARK: - Enhanced Smart List Support
    
    /// Evaluate smart list with enhanced rules
    nonisolated public func evaluateSmartListV2(_ smartList: SmartEpisodeListV2, allEpisodes: [Episode]) -> [Episode] {
        let filteredEpisodes = allEpisodes.filter { episode in
            smartListRuleEvaluator.evaluateSmartListRules(episode: episode, rules: smartList.rules)
        }
        
        let sortedEpisodes = sortService.sortEpisodes(filteredEpisodes, by: smartList.sortBy)
        
        if let maxEpisodes = smartList.maxEpisodes {
            return Array(sortedEpisodes.prefix(maxEpisodes))
        } else {
            return sortedEpisodes
        }
    }
    
    /// Check if smart list needs updating based on refresh interval
    nonisolated public func smartListNeedsUpdateV2(_ smartList: SmartEpisodeListV2) -> Bool {
        return smartList.needsUpdate()
    }
}

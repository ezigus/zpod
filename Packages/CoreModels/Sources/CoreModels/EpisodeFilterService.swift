import Foundation

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
    func searchEpisodes(_ episodes: [Episode], query: String, filter: EpisodeFilter?) -> [Episode]
    
    /// Update smart list with new episodes
    func updateSmartList(_ smartList: SmartEpisodeList, allEpisodes: [Episode]) -> [Episode]
    
    /// Check if smart list needs updating based on refresh interval
    func smartListNeedsUpdate(_ smartList: SmartEpisodeList) -> Bool
}

// MARK: - Default Implementation

public actor DefaultEpisodeFilterService: EpisodeFilterService {
    
    public init() {}
    
    nonisolated public func filterAndSort(episodes: [Episode], using filter: EpisodeFilter) -> [Episode] {
        let filteredEpisodes = applyFilter(episodes, filter: filter)
        return sortEpisodes(filteredEpisodes, by: filter.sortBy)
    }
    
    nonisolated public func episodeMatches(_ episode: Episode, condition: EpisodeFilterCondition) -> Bool {
        let matches = evaluateCondition(episode, condition.criteria)
        return condition.isNegated ? !matches : matches
    }
    
    nonisolated public func sortEpisodes(_ episodes: [Episode], by sortBy: EpisodeSortBy) -> [Episode] {
        switch sortBy {
        case .pubDateNewest:
            return episodes.sorted { (lhs, rhs) in
                guard let lhsDate = lhs.pubDate else { return false }
                guard let rhsDate = rhs.pubDate else { return true }
                return lhsDate > rhsDate
            }
            
        case .pubDateOldest:
            return episodes.sorted { (lhs, rhs) in
                guard let lhsDate = lhs.pubDate else { return true }
                guard let rhsDate = rhs.pubDate else { return false }
                return lhsDate < rhsDate
            }
            
        case .duration:
            return episodes.sorted { (lhs, rhs) in
                guard let lhsDuration = lhs.duration else { return false }
                guard let rhsDuration = rhs.duration else { return true }
                return lhsDuration < rhsDuration
            }
            
        case .title:
            return episodes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
        case .playStatus:
            return episodes.sorted { (lhs, rhs) in
                // Order: unplayed, in-progress, played
                let lhsStatus = playStatusValue(lhs)
                let rhsStatus = playStatusValue(rhs)
                return lhsStatus < rhsStatus
            }
            
        case .downloadStatus:
            return episodes.sorted { (lhs, rhs) in
                let lhsValue = downloadStatusValue(lhs.downloadStatus)
                let rhsValue = downloadStatusValue(rhs.downloadStatus)
                return lhsValue < rhsValue
            }
            
        case .rating:
            return episodes.sorted { (lhs, rhs) in
                let lhsRating = lhs.rating ?? 0
                let rhsRating = rhs.rating ?? 0
                return lhsRating > rhsRating // Higher ratings first
            }
            
        case .dateAdded:
            return episodes.sorted { $0.dateAdded > $1.dateAdded }
        }
    }
    
    /// Search episodes by text query
    nonisolated public func searchEpisodes(
        _ episodes: [Episode],
        query: String,
        filter: EpisodeFilter? = nil
    ) -> [Episode] {
        let searchResults = episodes.filter { episode in
            searchMatches(episode: episode, query: query)
        }
        
        if let filter = filter {
            return filterAndSort(episodes: searchResults, using: filter)
        } else {
            // Default sort by relevance (we could implement scoring here)
            return searchResults
        }
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
    
    // MARK: - Private Methods
    
    nonisolated private func applyFilter(_ episodes: [Episode], filter: EpisodeFilter) -> [Episode] {
        guard !filter.isEmpty else { return episodes }
        
        return episodes.filter { episode in
            switch filter.logic {
            case .and:
                return filter.conditions.allSatisfy { condition in
                    episodeMatches(episode, condition: condition)
                }
            case .or:
                return filter.conditions.contains { condition in
                    episodeMatches(episode, condition: condition)
                }
            }
        }
    }
    
    nonisolated private func evaluateCondition(_ episode: Episode, _ criteria: EpisodeFilterCriteria) -> Bool {
        switch criteria {
        case .unplayed:
            return !episode.isPlayed
        case .downloaded:
            return episode.isDownloaded
        case .favorited:
            return episode.isFavorited
        case .inProgress:
            return episode.isInProgress
        case .bookmarked:
            return episode.isBookmarked
        case .archived:
            return episode.isArchived
        case .rated:
            return episode.rating != nil
        case .unrated:
            return episode.rating == nil
        }
    }
    
    nonisolated private func playStatusValue(_ episode: Episode) -> Int {
        if !episode.isPlayed && episode.playbackPosition == 0 {
            return 0 // unplayed
        } else if episode.isInProgress {
            return 1 // in-progress
        } else {
            return 2 // played
        }
    }
    
    nonisolated private func downloadStatusValue(_ status: EpisodeDownloadStatus) -> Int {
        switch status {
        case .downloaded: return 0
        case .downloading: return 1
        case .notDownloaded: return 2
        case .failed: return 3
        }
    }
    
    nonisolated private func searchMatches(episode: Episode, query: String) -> Bool {
        let searchText = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { return true }
        
        // Search in title
        if episode.title.lowercased().contains(searchText) {
            return true
        }
        
        // Search in description
        if let description = episode.description,
           description.lowercased().contains(searchText) {
            return true
        }
        
        return false
    }
}
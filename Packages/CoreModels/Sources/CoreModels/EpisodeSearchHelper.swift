import Foundation

// MARK: - Episode Search Helper

/// Helper for basic episode search matching.
/// Value type (struct) marked Sendable for safe cross-actor usage.
public struct EpisodeSearchHelper: Sendable {
    
    public init() {}
    
    /// Search episodes by text query
    public func searchEpisodes(
        _ episodes: [Episode],
        query: String,
        filter: EpisodeFilter? = nil,
        includeArchived: Bool = false,
        filterEvaluator: EpisodeFilterEvaluator,
        sortService: EpisodeSortService
    ) -> [Episode] {
        // Exclude archived episodes by default unless explicitly requested
        let episodesToSearch = includeArchived ? episodes : episodes.filter { !$0.isArchived }
        
        let searchResults = episodesToSearch.filter { episode in
            searchMatches(episode: episode, query: query)
        }
        
        if let filter = filter {
            let filtered = filterEvaluator.applyFilter(searchResults, filter: filter)
            return sortService.sortEpisodes(filtered, by: filter.sortBy)
        } else {
            // Default sort by relevance (we could implement scoring here)
            return searchResults
        }
    }
    
    // MARK: - Private Helpers
    
    private func searchMatches(episode: Episode, query: String) -> Bool {
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

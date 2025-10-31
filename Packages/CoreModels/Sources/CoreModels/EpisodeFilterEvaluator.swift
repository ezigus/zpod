import Foundation

// MARK: - Episode Filter Evaluator

/// Helper for evaluating episode filter conditions.
/// Value type (struct) marked Sendable for safe cross-actor usage.
public struct EpisodeFilterEvaluator: Sendable {
    
    public init() {}
    
    /// Check if episode matches filter condition
    public func episodeMatches(_ episode: Episode, condition: EpisodeFilterCondition) -> Bool {
        let matches = evaluateCondition(episode, condition.criteria)
        return condition.isNegated ? !matches : matches
    }
    
    /// Apply filter to episodes
    public func applyFilter(_ episodes: [Episode], filter: EpisodeFilter) -> [Episode] {
        // Exclude archived episodes by default unless filter explicitly includes archived criteria
        let includesArchivedFilter = filter.conditions.contains { condition in
            condition.criteria == .archived && !condition.isNegated
        }
        
        let episodesToFilter = includesArchivedFilter ? episodes : episodes.filter { !$0.isArchived }
        
        guard !filter.isEmpty else { return episodesToFilter }
        
        return episodesToFilter.filter { episode in
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
    
    // MARK: - Private Helpers
    
    private func evaluateCondition(_ episode: Episode, _ criteria: EpisodeFilterCriteria) -> Bool {
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
}

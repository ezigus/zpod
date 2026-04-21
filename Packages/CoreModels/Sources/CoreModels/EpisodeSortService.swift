import Foundation

// MARK: - Episode Sort Service

/// Helper for sorting episodes by various criteria.
/// Value type (struct) marked Sendable for safe cross-actor usage.
public struct EpisodeSortService: Sendable {
    
    public init() {}
    
    /// Sort episodes by criteria using the sort type's default direction.
    public func sortEpisodes(_ episodes: [Episode], by sortBy: EpisodeSortBy) -> [Episode] {
        return sortEpisodes(episodes, by: sortBy, ascending: sortBy.defaultAscending)
    }

    /// Sort episodes by criteria with an explicit direction.
    /// Each case sorts in canonical ascending order; `ascending: false` reverses the result.
    /// Nil pubDate/duration values are pushed to the end regardless of direction.
    public func sortEpisodes(_ episodes: [Episode], by sortBy: EpisodeSortBy, ascending: Bool) -> [Episode] {
        let sorted: [Episode]
        switch sortBy {
        case .pubDateNewest, .pubDateOldest:
            // Both cases sort on pubDate; ascending = oldest first, descending = newest first.
            sorted = episodes.sorted { (lhs, rhs) in
                guard let lhsDate = lhs.pubDate else { return false } // nil = pushed to end in ascending
                guard let rhsDate = rhs.pubDate else { return true }
                return lhsDate < rhsDate
            }

        case .duration:
            sorted = episodes.sorted { (lhs, rhs) in
                guard let lhsDuration = lhs.duration else { return false }
                guard let rhsDuration = rhs.duration else { return true }
                return lhsDuration < rhsDuration
            }

        case .title:
            // localizedStandardCompare provides Finder-style natural sort ("Episode 2" before "Episode 10")
            sorted = episodes.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        case .playStatus:
            sorted = episodes.sorted { playStatusValue($0) < playStatusValue($1) }

        case .downloadStatus:
            sorted = episodes.sorted { downloadStatusValue($0.downloadStatus) < downloadStatusValue($1.downloadStatus) }

        case .rating:
            // ascending = lowest rating first; descending (default) = highest first
            sorted = episodes.sorted { ($0.rating ?? 0) < ($1.rating ?? 0) }

        case .dateAdded:
            // ascending = oldest added first; descending (default) = newest added first
            sorted = episodes.sorted { $0.dateAdded < $1.dateAdded }
        }
        return ascending ? sorted : sorted.reversed()
    }
    
    // MARK: - Private Helpers
    
    private func playStatusValue(_ episode: Episode) -> Int {
        if !episode.isPlayed && episode.playbackPosition == 0 {
            return 0 // unplayed
        } else if episode.isInProgress {
            return 1 // in-progress
        } else {
            return 2 // played
        }
    }
    
    private func downloadStatusValue(_ status: EpisodeDownloadStatus) -> Int {
        switch status {
        case .downloaded: return 0
        case .downloading: return 1
        case .paused: return 2
        case .notDownloaded: return 3
        case .failed: return 4
        }
    }
}

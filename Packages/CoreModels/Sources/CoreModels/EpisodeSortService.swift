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
    /// Nil pubDate/duration values are pushed to the end regardless of direction.
    public func sortEpisodes(_ episodes: [Episode], by sortBy: EpisodeSortBy, ascending: Bool) -> [Episode] {
        switch sortBy {
        case .pubDateNewest, .pubDateOldest:
            return episodes.sorted { (lhs, rhs) in
                // Nil values always sort to the end regardless of direction
                guard let lhsDate = lhs.pubDate else { return false }
                guard let rhsDate = rhs.pubDate else { return true }
                return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
            }

        case .duration:
            return episodes.sorted { (lhs, rhs) in
                guard let lhsDuration = lhs.duration else { return false }
                guard let rhsDuration = rhs.duration else { return true }
                return ascending ? lhsDuration < rhsDuration : lhsDuration > rhsDuration
            }

        case .title:
            // localizedStandardCompare provides Finder-style natural sort ("Episode 2" before "Episode 10")
            return episodes.sorted {
                let result = $0.title.localizedStandardCompare($1.title)
                return ascending ? result == .orderedAscending : result == .orderedDescending
            }

        case .playStatus:
            return episodes.sorted {
                let lv = playStatusValue($0), rv = playStatusValue($1)
                return ascending ? lv < rv : lv > rv
            }

        case .downloadStatus:
            return episodes.sorted {
                let lv = downloadStatusValue($0.downloadStatus), rv = downloadStatusValue($1.downloadStatus)
                return ascending ? lv < rv : lv > rv
            }

        case .rating:
            // nil rating treated as 0 (unrated = lowest) in both directions
            return episodes.sorted {
                let lr = $0.rating ?? 0, rr = $1.rating ?? 0
                return ascending ? lr < rr : lr > rr
            }

        case .dateAdded:
            return episodes.sorted {
                ascending ? $0.dateAdded < $1.dateAdded : $0.dateAdded > $1.dateAdded
            }
        }
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

import Foundation

// MARK: - Episode Sort Service

/// Helper for sorting episodes by various criteria.
/// Value type (struct) marked Sendable for safe cross-actor usage.
public struct EpisodeSortService: Sendable {
    
    public init() {}
    
    /// Sort episodes by criteria
    public func sortEpisodes(_ episodes: [Episode], by sortBy: EpisodeSortBy) -> [Episode] {
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

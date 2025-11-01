import Foundation
import CoreModels

/// Mock playlist engine for evaluating smart playlists and generating playback queues
///
/// This engine provides test implementations of playlist evaluation logic,
/// allowing tests to verify playlist behavior without full production dependencies.
///
/// @unchecked Sendable: This test-only implementation is stateless and safe to use
/// across concurrency boundaries.
public final class PlaylistEngine: @unchecked Sendable {
    
    public init() {}
    
    /// Evaluates a smart playlist against a collection of episodes
    ///
    /// - Parameters:
    ///   - smartPlaylist: The smart playlist configuration to evaluate
    ///   - episodes: Available episodes to filter
    ///   - downloadStatuses: Download state for each episode (keyed by episode ID)
    /// - Returns: Episodes matching the smart playlist criteria
    public func evaluateSmartPlaylist(
        _ smartPlaylist: SmartPlaylist,
        episodes: [Episode],
        downloadStatuses: [String: DownloadState]
    ) async -> [Episode] {
        var matchingEpisodes = episodes
        
        for filterRule in smartPlaylist.criteria.filterRules {
            matchingEpisodes = matchingEpisodes.filter { episode in
                matchesFilterRule(filterRule, episode: episode, downloadStatus: downloadStatuses[episode.id])
            }
        }
        
        if matchingEpisodes.count > smartPlaylist.criteria.maxEpisodes {
            matchingEpisodes = Array(matchingEpisodes.prefix(smartPlaylist.criteria.maxEpisodes))
        }
        
        return matchingEpisodes
    }
    
    /// Generates a playback queue from a playlist
    ///
    /// - Parameters:
    ///   - playlist: The playlist to generate a queue from
    ///   - episodes: Available episodes
    ///   - shuffle: Whether to shuffle the queue
    /// - Returns: Episodes in playback order
    public func generatePlaybackQueue(
        from playlist: Playlist,
        episodes: [Episode],
        shuffle: Bool = false
    ) async -> [Episode] {
        let matchingEpisodes = episodes.filter { episode in
            playlist.episodeIds.contains(episode.id)
        }
        
        if !shuffle || !playlist.shuffleAllowed {
            return playlist.episodeIds.compactMap { episodeId in
                matchingEpisodes.first { $0.id == episodeId }
            }
        } else {
            return matchingEpisodes.shuffled()
        }
    }
    
    private func matchesFilterRule(
        _ rule: SmartPlaylistFilterRule, 
        episode: Episode, 
        downloadStatus: DownloadState?
    ) -> Bool {
        switch rule {
        case .isPlayed(let isPlayed):
            return episode.isPlayed == isPlayed
        case .isDownloaded:
            return downloadStatus == .completed
        case .podcastCategory(_):
            return true // For testing purposes
        case .dateRange(let start, let end):
            guard let pubDate = episode.pubDate else { return false }
            return pubDate >= start && pubDate <= end
        case .durationRange(let min, let max):
            guard let duration = episode.duration else { return false }
            return duration >= min && duration <= max
        }
    }
}

import Foundation
import CoreModels

/// Protocol for managing episode state (played status, position, etc.)
public protocol EpisodeStateManager: Sendable {
    func setPlayedStatus(_ episode: Episode, isPlayed: Bool) async
    func updatePlaybackPosition(_ episode: Episode, position: TimeInterval) async
    func getEpisodeState(_ episode: Episode) async -> Episode
}

/// Simple in-memory implementation of episode state management
@MainActor
public final class InMemoryEpisodeStateManager: EpisodeStateManager {
    private var episodeStates: [String: Episode] = [:]
    
    public init() {}
    
    public func setPlayedStatus(_ episode: Episode, isPlayed: Bool) async {
        let updatedEpisode = episode.withPlayedStatus(isPlayed)
        episodeStates[episode.id] = updatedEpisode
    }
    
    public func updatePlaybackPosition(_ episode: Episode, position: TimeInterval) async {
        let updatedEpisode = episode.withPlaybackPosition(position)
        episodeStates[episode.id] = updatedEpisode
    }
    
    public func getEpisodeState(_ episode: Episode) async -> Episode {
        return episodeStates[episode.id] ?? episode
    }
}

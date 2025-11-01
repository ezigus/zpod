import Foundation
import CoreModels
import PlaybackEngine

/// Mock implementation of EpisodeStateManager for testing
///
/// This mock provides an in-memory implementation suitable for unit and integration tests.
/// It maintains episode state in an actor-isolated storage for thread-safe access.
///
/// @unchecked Sendable: This test-only implementation uses mutable state wrapped in an actor
/// for thread safety, making it safe to use across concurrency boundaries in tests.
public final class MockEpisodeStateManager: EpisodeStateManager, @unchecked Sendable {
    private actor Storage {
        private var episodes: [String: Episode] = [:]

        func update(_ episode: Episode) {
            episodes[episode.id] = episode
        }

        func episode(for id: String) -> Episode? {
            episodes[id]
        }
    }

    private let storage = Storage()

    public init() {}

    public func setPlayedStatus(_ episode: Episode, isPlayed: Bool) async {
        let updatedEpisode = episode.withPlayedStatus(isPlayed)
        await storage.update(updatedEpisode)
    }

    public func updatePlaybackPosition(_ episode: Episode, position: TimeInterval) async {
        let updatedEpisode = episode.withPlaybackPosition(Int(position))
        await storage.update(updatedEpisode)
    }

    public func updateEpisodeState(_ episode: Episode) async {
        await storage.update(episode)
    }

    public func getEpisodeState(_ episode: Episode) async -> Episode {
        await storage.episode(for: episode.id) ?? episode
    }
}

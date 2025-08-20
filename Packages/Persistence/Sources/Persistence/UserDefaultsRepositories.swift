@preconcurrency import Foundation
import CoreModels
import SharedUtilities

public protocol PodcastRepository: Sendable {
    func savePodcast(_ podcast: Podcast) async throws
    func loadPodcast(id: String) async throws -> Podcast?
}

public protocol EpisodeRepository: Sendable {
    func saveEpisode(_ episode: Episode) async throws
    func loadEpisode(id: String) async throws -> Episode?
}

public actor UserDefaultsPodcastRepository: PodcastRepository {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let keyPrefix = "podcast:"

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public func savePodcast(_ podcast: Podcast) async throws {
        do {
            let data = try encoder.encode(podcast)
            userDefaults.set(data, forKey: keyPrefix + podcast.id)
        } catch {
            throw SharedError.persistenceError("Failed to encode podcast: \(error)")
        }
    }

    public func loadPodcast(id: String) async throws -> Podcast? {
        guard let data = userDefaults.data(forKey: keyPrefix + id) else { return nil }
        do {
            return try decoder.decode(Podcast.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode podcast: \(error)")
        }
    }
}

public actor UserDefaultsEpisodeRepository: EpisodeRepository {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let keyPrefix = "episode:"

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public func saveEpisode(_ episode: Episode) async throws {
        do {
            let data = try encoder.encode(episode)
            userDefaults.set(data, forKey: keyPrefix + episode.id)
        } catch {
            throw SharedError.persistenceError("Failed to encode episode: \(error)")
        }
    }

    public func loadEpisode(id: String) async throws -> Episode? {
        guard let data = userDefaults.data(forKey: keyPrefix + id) else { return nil }
        do {
            return try decoder.decode(Episode.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode episode: \(error)")
        }
    }
}

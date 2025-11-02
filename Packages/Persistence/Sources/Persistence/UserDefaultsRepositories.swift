@preconcurrency import Foundation
import OSLog
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
    private static let logger = Logger(subsystem: "us.zig.zpod", category: "UserDefaultsPodcastRepository")
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let keyPrefix = "podcast:"

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public init(suiteName: String) {
        if let suiteDefaults = UserDefaults(suiteName: suiteName) {
            self.userDefaults = suiteDefaults
        } else {
            self.userDefaults = .standard
        }
    }

    public func savePodcast(_ podcast: Podcast) async throws {
        do {
            let data = try encoder.encode(podcast)
            userDefaults.set(data, forKey: keyPrefix + podcast.id)
            if #available(iOS 14.0, *) {
                persistSiriSnapshots()
            }
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

    public init(suiteName: String) {
        if let suiteDefaults = UserDefaults(suiteName: suiteName) {
            self.userDefaults = suiteDefaults
        } else {
            self.userDefaults = .standard
        }
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

@available(iOS 14.0, *)
extension UserDefaultsPodcastRepository {
    private func persistSiriSnapshots() {
        let dictionary = userDefaults.dictionaryRepresentation()
        var podcasts: [Podcast] = []

        for (key, value) in dictionary where key.hasPrefix(keyPrefix) {
            guard let data = value as? Data else { continue }
            if let podcast = try? decoder.decode(Podcast.self, from: data), podcast.isSubscribed {
                podcasts.append(podcast)
            }
        }

        let snapshots = podcasts
            .map(Self.makeSnapshot)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        do {
            if let sharedDefaults = UserDefaults(suiteName: AppGroup.suiteName) {
                try SiriMediaLibrary.save(snapshots, to: sharedDefaults)
            }

            if let devDefaults = UserDefaults(suiteName: AppGroup.devSuiteName) {
                try SiriMediaLibrary.save(snapshots, to: devDefaults)
            }
        } catch {
            Self.logger.warning("Failed to persist Siri snapshots: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func makeSnapshot(from podcast: Podcast) -> SiriPodcastSnapshot {
        let episodes = podcast.episodes.map { episode in
            SiriEpisodeSnapshot(
                id: episode.id,
                title: episode.title,
                duration: episode.duration,
                playbackPosition: episode.playbackPosition,
                isPlayed: episode.isPlayed,
                publishedAt: episode.pubDate
            )
        }

        return SiriPodcastSnapshot(id: podcast.id, title: podcast.title, episodes: episodes)
    }
}

import Foundation
import OSLog
import CoreModels
import Persistence
import SharedUtilities

// SiriSnapshotRefreshing protocol is now in CoreModels

@available(iOS 14.0, *)
struct SiriSnapshotCoordinator {
    private let logger = Logger(subsystem: "us.zig.zpod", category: "SiriSnapshotCoordinator")
    private let podcastManager: PodcastManaging
    private let primarySuiteName: String
    private let devSuiteName: String
    private let episodeSnapshotProvider: EpisodeSnapshotProviding?

    init(
        podcastManager: PodcastManaging,
        episodeSnapshotProvider: EpisodeSnapshotProviding? = nil,
        primarySuiteName: String = AppGroup.suiteName,
        devSuiteName: String = AppGroup.devSuiteName
    ) {
        self.podcastManager = podcastManager
        self.episodeSnapshotProvider = episodeSnapshotProvider
        self.primarySuiteName = primarySuiteName
        self.devSuiteName = devSuiteName
    }

    func refreshAll() {
        let snapshots = makeSnapshots()
        let primarySuiteName = primarySuiteName
        let devSuiteName = devSuiteName

        Task.detached(priority: .background) {
            Self.persistSnapshots(
                snapshots,
                primarySuiteName: primarySuiteName,
                devSuiteName: devSuiteName
            )
        }
    }

    /// Synchronous snapshot refresh for tests to avoid timing flakiness.
    func refreshAllForTesting() {
        let snapshots = makeSnapshots()
        Self.persistSnapshots(
            snapshots,
            primarySuiteName: primarySuiteName,
            devSuiteName: devSuiteName
        )
    }

    private func makeSnapshots() -> [SiriPodcastSnapshot] {
        let podcasts = podcastManager.all().filter { $0.isSubscribed }
        let episodeMap = makeEpisodeMap(for: podcasts)
        return podcasts
            .map { Self.makeSnapshot(from: $0, cachedEpisodes: episodeMap[$0.id]) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func makeEpisodeMap(for podcasts: [Podcast]) -> [String: [Episode]] {
        let episodeList: [Episode]
        if let provider = episodeSnapshotProvider {
            let subscribedIds = Set(podcasts.map { $0.id })
            episodeList = provider.allEpisodes().filter { episode in
                guard let podcastId = episode.podcastID else { return false }
                return subscribedIds.contains(podcastId)
            }
        } else {
            episodeList = podcasts.flatMap { $0.episodes }
        }

        return Dictionary(grouping: episodeList) { $0.podcastID ?? "" }
    }

    private static func persistSnapshots(
        _ snapshots: [SiriPodcastSnapshot],
        primarySuiteName: String,
        devSuiteName: String
    ) {
        let logger = Logger(subsystem: "us.zig.zpod", category: "SiriSnapshotCoordinator")
        do {
            if let sharedDefaults = UserDefaults(suiteName: primarySuiteName) {
                try SiriMediaLibrary.save(snapshots, to: sharedDefaults)
            }

            if let devDefaults = UserDefaults(suiteName: devSuiteName) {
                try SiriMediaLibrary.save(snapshots, to: devDefaults)
            }
        } catch {
            logger.error("Failed to persist Siri snapshots: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func makeSnapshot(from podcast: Podcast, cachedEpisodes: [Episode]?) -> SiriPodcastSnapshot {
        let sourceEpisodes = cachedEpisodes ?? podcast.episodes
        let episodes = sourceEpisodes.map { episode in
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

@available(iOS 14.0, *)
extension SiriSnapshotCoordinator: SiriSnapshotRefreshing {}

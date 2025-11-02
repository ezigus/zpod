import Foundation
import OSLog
import CoreModels
import SharedUtilities

@available(iOS 14.0, *)
struct SiriSnapshotCoordinator {
    private let logger = Logger(subsystem: "us.zig.zpod", category: "SiriSnapshotCoordinator")
    private let podcastManager: PodcastManaging

    init(podcastManager: PodcastManaging) {
        self.podcastManager = podcastManager
    }

    func refreshAll() {
        Task.detached(priority: .background) {
            await persistAllPodcasts()
        }
    }

    private func persistAllPodcasts() async {
        let podcasts = podcastManager.all().filter { $0.isSubscribed }
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
            logger.error("Failed to persist Siri snapshots: \(error.localizedDescription, privacy: .public)")
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

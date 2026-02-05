import CombineSupport
import CoreModels
import Foundation
import Networking
import SharedUtilities

@MainActor
public final class DownloadCoordinatorBridge: DownloadProgressProviding, EpisodeDownloadEnqueuing {
    public static let shared = DownloadCoordinatorBridge()

    private let coordinator: DownloadCoordinator

    private init() {
        self.coordinator = DownloadCoordinator(autoProcessingEnabled: true)
    }

    public var progressPublisher: AnyPublisher<EpisodeDownloadProgressUpdate, Never> {
        coordinator.episodeProgressPublisher
    }

    public func downloadEpisode(_ episodeID: String) async throws {
        coordinator.requestDownload(forEpisodeID: episodeID)
    }

    public func cancelDownload(_ episodeID: String) async {
        coordinator.cancelDownload(forEpisodeID: episodeID)
    }

    public func pauseDownload(_ episodeID: String) async {
        coordinator.pauseDownload(forEpisodeID: episodeID)
    }

    public func resumeDownload(_ episodeID: String) async {
        coordinator.resumeDownload(forEpisodeID: episodeID)
    }

    public func enqueueEpisode(_ episode: Episode) {
        coordinator.addDownload(for: episode)
    }

    /// Get local file URL for a downloaded episode (for offline playback)
    public func localFileURL(for episodeId: String) -> URL? {
        return coordinator.localFileURL(for: episodeId)
    }

    /// Check if episode has been downloaded
    public func isDownloaded(episodeId: String) -> Bool {
        return coordinator.isDownloaded(episodeId: episodeId)
    }

    /// Get all downloaded episode IDs
    public func getAllDownloadedEpisodeIds() -> [String] {
        return coordinator.getAllDownloadedEpisodeIds()
    }

    /// Delete a downloaded episode
    public func deleteDownloadedEpisode(episodeId: String) async throws {
        try await coordinator.deleteDownloadedEpisode(episodeId: episodeId)
    }

    /// Delete all downloaded episodes
    @discardableResult
    public func deleteAllDownloads() async throws -> Int {
        return try await coordinator.deleteAllDownloads()
    }

    /// Seed completed downloads for UI tests using a comma-separated list.
    /// Supports optional podcast prefix: "podcastA:ep1,podcastB:ep2".
    /// No-op outside UI test environment (guarded by env var check in caller).
    public func seedDownloadsForUITests(from envValue: String) async {
        let entries: [(podcastId: String, episodeId: String)] = envValue
            .split(separator: ",")
            .map { token in
                let parts = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                if parts.count == 2 {
                    return (podcastId: String(parts[0]), episodeId: String(parts[1]))
                } else {
                    return (podcastId: "uitest-podcast", episodeId: String(token))
                }
            }

        do {
            try await coordinator.seedCompletedDownloads(entries)
            Logger.info("✅ UI Test: Download seeding completed (\(entries.count) episodes)")
        } catch {
            Logger.error("❌ UI Test: Download seeding failed: \(error)")
        }
    }

    /// Seed downloads from UITEST_DOWNLOADED_EPISODES if present. No-op outside UITest.
    /// Runs asynchronously - StorageManagementViewModel uses fallback stats for deterministic UI.
    public func ensureUITestSeededFromEnvIfNeeded() async {
        guard let env = ProcessInfo.processInfo.environment["UITEST_DOWNLOADED_EPISODES"],
              !env.isEmpty
        else {
            // No env var = not a UI test, skip silently
            return
        }

        Logger.info("🧪 UI Test: Seeding downloads from env: \(env)")
        await seedDownloadsForUITests(from: env)
        Logger.info("✅ UI Test: Download seeding completed")
    }
}

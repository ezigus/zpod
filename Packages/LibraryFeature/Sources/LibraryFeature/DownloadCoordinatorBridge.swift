import CombineSupport
import CoreModels
import Foundation
import Networking

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
}

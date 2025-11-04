import CombineSupport
import CoreModels
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
}

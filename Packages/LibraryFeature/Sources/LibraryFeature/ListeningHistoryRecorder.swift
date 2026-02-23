#if canImport(Combine)
@preconcurrency import Combine
#endif
import CoreModels
import Foundation
import Persistence
import PlaybackEngine
import SharedUtilities

/// Observes playback state changes and records listening history entries.
///
/// Subscribes to `EpisodePlaybackService.statePublisher` and records a
/// `PlaybackHistoryEntry` each time an episode finishes. Respects the
/// privacy toggle — when disabled, no entries are written.
///
/// Lives in LibraryFeature because it depends on both PlaybackEngine
/// (via the service protocol) and Persistence (via the repository).
@MainActor
public final class ListeningHistoryRecorder {

    private let repository: ListeningHistoryRepository
    private let privacySettings: ListeningHistoryPrivacyProvider
    private let playbackSpeedProvider: () -> Double

    #if canImport(Combine)
    private var cancellable: AnyCancellable?
    #endif

    /// Creates a recorder that automatically observes playback events.
    ///
    /// - Parameters:
    ///   - repository: Where to persist history entries.
    ///   - privacySettings: Controls whether recording is enabled.
    ///   - playbackSpeedProvider: Returns the current playback speed at recording time.
    ///   - statePublisher: The playback state publisher to observe.
    public init(
        repository: ListeningHistoryRepository,
        privacySettings: ListeningHistoryPrivacyProvider,
        playbackSpeedProvider: @escaping () -> Double
    ) {
        self.repository = repository
        self.privacySettings = privacySettings
        self.playbackSpeedProvider = playbackSpeedProvider
    }

    #if canImport(Combine)
    /// Start observing a playback state publisher.
    /// Call this once after initialization to begin recording.
    public func startObserving(publisher: AnyPublisher<EpisodePlaybackState, Never>) {
        cancellable = publisher
            .sink { [weak self] state in
                guard let self else { return }
                self.handleStateChange(state)
            }
    }
    #endif

    /// Stop observing playback events.
    public func stopObserving() {
        #if canImport(Combine)
        cancellable?.cancel()
        cancellable = nil
        #endif
    }

    // MARK: - Private

    private func handleStateChange(_ state: EpisodePlaybackState) {
        guard privacySettings.isListeningHistoryEnabled() else { return }

        switch state {
        case .finished(let episode, let duration):
            recordEntry(for: episode, duration: duration, completed: true)
        case .playing, .paused, .idle, .failed:
            break
        }
    }

    private func recordEntry(for episode: Episode, duration: TimeInterval, completed: Bool) {
        let entry = PlaybackHistoryEntry(
            episodeId: episode.id,
            podcastId: episode.podcastID ?? "",
            playedAt: Date(),
            duration: duration,
            completed: completed,
            episodeTitle: episode.title,
            podcastTitle: episode.podcastTitle,
            playbackSpeed: playbackSpeedProvider()
        )
        repository.record(entry)
    }
}

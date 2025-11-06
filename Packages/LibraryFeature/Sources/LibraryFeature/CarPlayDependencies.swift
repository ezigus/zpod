import CoreModels
import Foundation
import PlaybackEngine
import Persistence

#if canImport(Combine)
  import CombineSupport
#endif

/// Bundles dependencies required by the CarPlay integration.
@MainActor
public struct CarPlayDependencies {
  public let podcastManager: any PodcastManaging
  public let playbackService: EpisodePlaybackService & EpisodeTransportControlling
  public let queueManager: CarPlayQueueManaging
  public let playbackStateCoordinator: PlaybackStateCoordinator?

  public init(
    podcastManager: any PodcastManaging,
    playbackService: EpisodePlaybackService & EpisodeTransportControlling,
    queueManager: CarPlayQueueManaging,
    playbackStateCoordinator: PlaybackStateCoordinator? = nil
  ) {
    self.podcastManager = podcastManager
    self.playbackService = playbackService
    self.queueManager = queueManager
    self.playbackStateCoordinator = playbackStateCoordinator
  }
}

/// Protocol that coordinates CarPlay playback actions and queue management.
@MainActor
public protocol CarPlayQueueManaging: AnyObject {
  func playNow(_ episode: Episode)
  func enqueue(_ episode: Episode)
  var queuedEpisodes: [Episode] { get }
}

/// Default queue coordinator that advances through an in-memory queue.
@MainActor
public final class CarPlayPlaybackCoordinator: CarPlayQueueManaging {
  private let playbackService: EpisodePlaybackService
  private(set) public var queuedEpisodes: [Episode] = []

  #if canImport(Combine)
    private var cancellable: AnyCancellable?
  #endif

  public init(playbackService: EpisodePlaybackService) {
    self.playbackService = playbackService

    #if canImport(Combine)
      cancellable = playbackService.statePublisher.sink { [weak self] state in
        self?.handlePlaybackState(state)
      }
    #endif
  }

  public func playNow(_ episode: Episode) {
    playbackService.play(episode: episode, duration: episode.duration)
    queuedEpisodes.removeAll(where: { $0.id == episode.id })
  }

  public func enqueue(_ episode: Episode) {
    guard !queuedEpisodes.contains(where: { $0.id == episode.id }) else { return }
    queuedEpisodes.append(episode)
  }

  @MainActor
  private func advanceQueue() {
    guard let next = queuedEpisodes.first else { return }
    queuedEpisodes.removeFirst()
    playbackService.play(episode: next, duration: next.duration)
  }

  #if canImport(Combine)
    private func handlePlaybackState(_ state: EpisodePlaybackState) {
      switch state {
      case .finished:
        advanceQueue()
      case .idle:
        // If playback idles (e.g., user stopped), keep queue as-is.
        break
      case .playing, .paused:
        break
      }
    }
  #endif
}

/// Provides configurable dependencies for CarPlay-specific surfaces.
@MainActor
public enum CarPlayDependencyRegistry {
  private static var customResolver: (() -> CarPlayDependencies)?
  private static var cachedDependencies: CarPlayDependencies?

  public static func configure(_ resolver: @escaping () -> CarPlayDependencies) {
    customResolver = resolver
    cachedDependencies = nil
  }

  public static func configure(podcastManager: any PodcastManaging) {
    configure {
      defaultDependencies(podcastManagerOverride: podcastManager)
    }
  }

  public static func reset() {
    customResolver = nil
    cachedDependencies = nil
  }

  @MainActor
  public static func resolve() -> CarPlayDependencies {
    if let cached = cachedDependencies { return cached }
    let dependencies = (customResolver?() ?? defaultDependencies())
    cachedDependencies = dependencies
    return dependencies
  }

  @MainActor
  private static func defaultDependencies(podcastManagerOverride: (any PodcastManaging)? = nil)
    -> CarPlayDependencies
  {
    let podcastManager = podcastManagerOverride ?? EmptyPodcastManager()
    let playback = EnhancedEpisodePlayer()
    let queueCoordinator = CarPlayPlaybackCoordinator(playbackService: playback)
    
    // Create settings repository and playback state coordinator
    let settingsRepository = UserDefaultsSettingsRepository()
    let stateCoordinator = PlaybackStateCoordinator(
      playbackService: playback,
      settingsRepository: settingsRepository,
      episodeLookup: { episodeId in
        // Look up episode across all podcasts
        for podcast in podcastManager.all() {
          if let episode = podcast.episodes.first(where: { $0.id == episodeId }) {
            return episode
          }
        }
        return nil
      }
    )
    
    // Restore playback state on initialization
    Task { @MainActor in
      await stateCoordinator.restorePlaybackIfNeeded()
    }
    
    return CarPlayDependencies(
      podcastManager: podcastManager,
      playbackService: playback,
      queueManager: queueCoordinator,
      playbackStateCoordinator: stateCoordinator
    )
  }
}

/// Lightweight fallback podcast manager used when the host app does not provide one.
private final class EmptyPodcastManager: PodcastManaging {
  func all() -> [Podcast] { [] }
  func find(id: String) -> Podcast? { nil }
  func add(_ podcast: Podcast) {}
  func update(_ podcast: Podcast) {}
  func remove(id: String) {}
  func findByFolder(folderId: String) -> [Podcast] { [] }
  func findByFolderRecursive(folderId: String, folderManager: any FolderManaging) -> [Podcast] {
    []
  }
  func findByTag(tagId: String) -> [Podcast] { [] }
  func findUnorganized() -> [Podcast] { [] }
}

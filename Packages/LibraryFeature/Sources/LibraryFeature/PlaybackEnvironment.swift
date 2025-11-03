import CoreModels
import PlaybackEngine

/// Provides a shared view of playback dependencies for iPhone, CarPlay, and Siri surfaces.
@MainActor
public enum PlaybackEnvironment {
  private static var overrideResolver: (() -> CarPlayDependencies)?

  /// Allow tests to override the dependency resolver.
  public static func configure(_ resolver: @escaping () -> CarPlayDependencies) {
    overrideResolver = resolver
  }

  /// Reset to production defaults.
  public static func reset() {
    overrideResolver = nil
  }

  /// Access the shared CarPlay-aware dependency bundle.
  public static var dependencies: CarPlayDependencies {
    if let resolver = overrideResolver {
      return resolver()
    }
    return CarPlayDependencyRegistry.resolve()
  }

  /// Shared playback service used across mini-player, episode detail, and CarPlay coordinators.
  public static var playbackService: EpisodePlaybackService & EpisodeTransportControlling {
    dependencies.playbackService
  }

  /// Shared queue status provider that exposes upcoming episodes.
  public static var queueManager: CarPlayQueueManaging {
    dependencies.queueManager
  }

  public static var podcastManager: any PodcastManaging {
    dependencies.podcastManager
  }
}

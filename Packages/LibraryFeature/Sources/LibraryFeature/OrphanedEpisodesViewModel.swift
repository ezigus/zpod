import CoreModels
import Foundation
import PlaybackEngine
import SharedUtilities

@MainActor
public final class OrphanedEpisodesViewModel: ObservableObject {
  @Published public private(set) var episodes: [Episode] = []
  @Published public private(set) var isLoading = false
  @Published public var showDeleteAllConfirmation = false
  private let podcastManager: any PodcastManaging
  private let injectedPlaybackCoordinator: EpisodePlaybackCoordinating?
  private lazy var playbackCoordinator: EpisodePlaybackCoordinating = {
    if let injectedPlaybackCoordinator {
      return injectedPlaybackCoordinator
    }
    return EpisodePlaybackCoordinator(
      playbackService: PlaybackEnvironment.playbackService,
      episodeLookup: { [weak self] id in
        guard let self else { return nil }
        return self.episodes.first(where: { $0.id == id })
      },
      episodeUpdateHandler: { [weak self] updated in
        guard let self else { return }
        if let index = self.episodes.firstIndex(where: { $0.id == updated.id }) {
          self.episodes[index] = updated
        }
      }
    )
  }()

  public init(
    podcastManager: any PodcastManaging,
    playbackCoordinator: EpisodePlaybackCoordinating? = nil
  ) {
    self.podcastManager = podcastManager
    self.injectedPlaybackCoordinator = playbackCoordinator
  }

  public func load() async {
    isLoading = true
    let fetched = await fetch()
    self.episodes = fetched
    isLoading = false
  }

  public func delete(_ episode: Episode) async {
    let manager = podcastManager
    _ = await Task.detached {
      manager.deleteOrphanedEpisode(id: episode.id)
    }.value
    await load()
  }

  public func deleteAll() async {
    let manager = podcastManager
    _ = await Task.detached {
      manager.deleteAllOrphanedEpisodes()
    }.value
    await load()
  }

  public func quickPlayEpisode(_ episode: Episode) async {
    await playbackCoordinator.quickPlayEpisode(episode)
  }

  private func fetch() async -> [Episode] {
    let manager = podcastManager
    return await Task.detached {
      manager.fetchOrphanedEpisodes()
    }.value
  }
}

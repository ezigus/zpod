import CoreModels
import Foundation
import SharedUtilities

@MainActor
public final class OrphanedEpisodesViewModel: ObservableObject {
  @Published public private(set) var episodes: [Episode] = []
  @Published public private(set) var isLoading = false
  @Published public var showDeleteAllConfirmation = false
  private let podcastManager: any PodcastManaging

  public init(podcastManager: any PodcastManaging) {
    self.podcastManager = podcastManager
  }

  public func load() async {
    isLoading = true
    let fetched = await fetch()
    self.episodes = fetched
    isLoading = false
  }

  public func delete(_ episode: Episode) async {
    _ = await withCheckedContinuation { continuation in
      Task.detached {
        let removed = self.podcastManager.deleteOrphanedEpisode(id: episode.id)
        continuation.resume(returning: removed)
      }
    }
    await load()
  }

  public func deleteAll() async {
    _ = await withCheckedContinuation { continuation in
      Task.detached {
        let count = self.podcastManager.deleteAllOrphanedEpisodes()
        continuation.resume(returning: count)
      }
    }
    await load()
  }

  private func fetch() async -> [Episode] {
    await withCheckedContinuation { continuation in
      Task.detached {
        let items = self.podcastManager.fetchOrphanedEpisodes()
        continuation.resume(returning: items)
      }
    }
  }
}

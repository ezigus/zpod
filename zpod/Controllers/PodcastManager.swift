import Foundation
import CoreModels

/// Protocol defining podcast library management responsibilities.
/// Design reference: dev-log entry "Xcode Project Scaffolding & Initial Manager/View Stubs" (2025-08-10).
public typealias PodcastManaging = CoreModels.PodcastManaging

/// In-memory implementation suitable for early development & unit testing.
/// Thread-safety: Not yet synchronized; assume single-threaded access for initial phase.
/// 
/// @unchecked Sendable: This implementation uses mutable state but is designed for
/// single-threaded access patterns during early development. Production implementations
/// should use proper synchronization mechanisms.
public final class InMemoryPodcastManager: PodcastManaging, @unchecked Sendable {
  private var storage: [String: Podcast] = [:]
  private let siriAppGroupSuite = "group.us.zig.zpod"
  private let siriDevSuite = "dev.us.zig.zpod"
  private let siriStorageKey = "carplay.podcastSnapshots"

  public init(initial: [Podcast] = []) {
    for p in initial { storage[p.id] = p }
    persistSiriSnapshots()
  }

  public func all() -> [Podcast] { Array(storage.values) }

  public func find(id: String) -> Podcast? { storage[id] }

  public func add(_ podcast: Podcast) {
    // Enforce id uniqueness; ignore if already present (could log later)
    guard storage[podcast.id] == nil else { return }
    storage[podcast.id] = podcast
    persistSiriSnapshots()
  }

  public func update(_ podcast: Podcast) {
    guard let existing = storage[podcast.id] else { return }
    // Determine if the only intended change is subscription status
    let sameExceptSubscription = (
      existing.title == podcast.title &&
      existing.author == podcast.author &&
      existing.description == podcast.description &&
      existing.artworkURL == podcast.artworkURL &&
      existing.feedURL == podcast.feedURL &&
      existing.categories == podcast.categories &&
      existing.episodes == podcast.episodes &&
      existing.dateAdded == podcast.dateAdded &&
      existing.folderId == podcast.folderId &&
      existing.tagIds == podcast.tagIds
    )

    let resolvedIsSubscribed = sameExceptSubscription ? podcast.isSubscribed : existing.isSubscribed

    // Preserve original added date; metadata updates should not alter it
    let merged = Podcast(
      id: podcast.id,
      title: podcast.title,
      author: podcast.author,
      description: podcast.description,
      artworkURL: podcast.artworkURL,
      feedURL: podcast.feedURL,
      categories: podcast.categories,
      episodes: podcast.episodes,
      isSubscribed: resolvedIsSubscribed,
      dateAdded: existing.dateAdded,
      folderId: podcast.folderId,
      tagIds: podcast.tagIds
    )
    storage[podcast.id] = merged
    persistSiriSnapshots()
  }

  public func remove(id: String) {
    storage.removeValue(forKey: id)
    persistSiriSnapshots()
  }
  
  // MARK: - Organization Filtering
  
  public func findByFolder(folderId: String) -> [Podcast] {
    storage.values.filter { $0.folderId == folderId }
  }
  
  public func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] {
    // Get direct podcasts in this folder
    var podcasts = findByFolder(folderId: folderId)
    
    // Get podcasts from all descendant folders
    let descendants = folderManager.getDescendants(of: folderId)
    for descendant in descendants {
      podcasts.append(contentsOf: findByFolder(folderId: descendant.id))
    }
    
    return podcasts
  }
  
  public func findByTag(tagId: String) -> [Podcast] {
    storage.values.filter { $0.tagIds.contains(tagId) }
  }
  
  public func findUnorganized() -> [Podcast] {
    storage.values.filter { $0.folderId == nil && $0.tagIds.isEmpty }
  }

  private func persistSiriSnapshots() {
    guard #available(iOS 14.0, *) else { return }

    let podcastSnapshots = storage.values.map { podcast -> SiriPodcastSnapshot in
      let episodes = podcast.episodes.map { episode -> SiriEpisodeSnapshot in
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

    let encoder = JSONEncoder()

    if let sharedDefaults = UserDefaults(suiteName: siriAppGroupSuite),
      let data = try? encoder.encode(podcastSnapshots)
    {
      sharedDefaults.set(data, forKey: siriStorageKey)
      sharedDefaults.synchronize()
    }

    if let devDefaults = UserDefaults(suiteName: siriDevSuite),
      let data = try? encoder.encode(podcastSnapshots)
    {
      devDefaults.set(data, forKey: siriStorageKey)
      devDefaults.synchronize()
    }
  }
}

@available(iOS 14.0, *)
private struct SiriPodcastSnapshot: Codable {
  let id: String
  let title: String
  let episodes: [SiriEpisodeSnapshot]
}

@available(iOS 14.0, *)
private struct SiriEpisodeSnapshot: Codable {
  let id: String
  let title: String
  let duration: TimeInterval?
  let playbackPosition: Int?
  let isPlayed: Bool
  let publishedAt: Date?
}

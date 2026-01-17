import Foundation
import CoreModels

/// In-memory implementation suitable for early development & unit testing.
/// Thread-safety: Not yet synchronized; assume single-threaded access for initial phase.
///
/// @unchecked Sendable: This test-only implementation uses mutable state but is designed
/// for single-threaded test scenarios where thread safety is not required. The @unchecked
/// annotation acknowledges this intentional design limitation for testing purposes.
public final class InMemoryPodcastManager: PodcastManaging, @unchecked Sendable {
  private var storage: [String: Podcast] = [:]
  private let siriSnapshotRefresher: SiriSnapshotRefreshing?

  public init(initial: [Podcast] = [], siriSnapshotRefresher: SiriSnapshotRefreshing? = nil) {
    self.siriSnapshotRefresher = siriSnapshotRefresher
    for p in initial { storage[p.id] = p }
  }

  public func all() -> [Podcast] { Array(storage.values) }

  public func find(id: String) -> Podcast? { storage[id] }

  public func add(_ podcast: Podcast) {
    // Enforce id uniqueness; ignore if already present (could log later)
    guard storage[podcast.id] == nil else { return }
    storage[podcast.id] = podcast
    siriSnapshotRefresher?.refreshAll()
  }

  public func update(_ podcast: Podcast) {
    guard let existing = storage[podcast.id] else { return }
    let resolvedIsSubscribed = podcast.isSubscribed != existing.isSubscribed
      ? podcast.isSubscribed
      : existing.isSubscribed

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
    siriSnapshotRefresher?.refreshAll()
  }

  public func remove(id: String) {
    guard storage.removeValue(forKey: id) != nil else { return }
    siriSnapshotRefresher?.refreshAll()
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

  // MARK: - Test Utilities

  /// Resets all episode playback positions to 0 across all podcasts.
  /// Used by UI tests to ensure clean state between test runs.
  public func resetAllPlaybackPositions() {
    guard !storage.isEmpty else { return }

    var updatedStorage = storage
    var didUpdate = false

    for (id, podcast) in storage {
      guard !podcast.episodes.isEmpty else { continue }

      let resetEpisodes = podcast.episodes.map { episode in
        episode.withPlaybackPosition(0)
      }
      let updatedPodcast = Podcast(
        id: podcast.id,
        title: podcast.title,
        author: podcast.author,
        description: podcast.description,
        artworkURL: podcast.artworkURL,
        feedURL: podcast.feedURL,
        categories: podcast.categories,
        episodes: resetEpisodes,
        isSubscribed: podcast.isSubscribed,
        dateAdded: podcast.dateAdded,
        folderId: podcast.folderId,
        tagIds: podcast.tagIds
      )
      updatedStorage[id] = updatedPodcast
      didUpdate = true
    }

    guard didUpdate else { return }
    storage = updatedStorage
    siriSnapshotRefresher?.refreshAll()
  }
}

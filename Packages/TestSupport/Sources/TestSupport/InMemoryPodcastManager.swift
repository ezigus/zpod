import Foundation
import CoreModels

/// In-memory implementation suitable for early development & unit testing.
/// Thread-safety: Not yet synchronized; assume single-threaded access for initial phase.
public final class InMemoryPodcastManager: PodcastManaging {
  private var storage: [String: Podcast] = [:]

  public init(initial: [Podcast] = []) {
    for p in initial { storage[p.id] = p }
  }

  public func all() -> [Podcast] { Array(storage.values) }

  public func find(id: String) -> Podcast? { storage[id] }

  public func add(_ podcast: Podcast) {
    // Enforce id uniqueness; ignore if already present (could log later)
    guard storage[podcast.id] == nil else { return }
    storage[podcast.id] = podcast
  }

  public func update(_ podcast: Podcast) {
    guard storage[podcast.id] != nil else { return }
    storage[podcast.id] = podcast
  }

  public func remove(id: String) { storage.removeValue(forKey: id) }
  
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
}
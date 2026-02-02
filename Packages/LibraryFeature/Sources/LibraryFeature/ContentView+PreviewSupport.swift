//
//  ContentView+PreviewSupport.swift
//  LibraryFeature
//
//  Preview-only helpers for ContentView.
//

#if DEBUG && (os(iOS) || os(macOS))

import CoreModels
import Foundation

/// Preview-only in-memory manager for ContentView previews.
/// @unchecked Sendable: uses a lock to guard local state for preview usage.
final class PreviewPodcastManager: PodcastManaging, @unchecked Sendable {
  private var storage: [String: Podcast]
  private let lock = NSLock()

  init(initial: [Podcast] = PreviewPodcastData.podcasts) {
    var map: [String: Podcast] = [:]
    for podcast in initial {
      map[podcast.id] = podcast
    }
    self.storage = map
  }

  func all() -> [Podcast] {
    locked { Array(storage.values) }
  }

  func find(id: String) -> Podcast? {
    locked { storage[id] }
  }

  func add(_ podcast: Podcast) {
    locked {
      guard storage[podcast.id] == nil else { return }
      storage[podcast.id] = podcast
    }
  }

  func update(_ podcast: Podcast) {
    locked { storage[podcast.id] = podcast }
  }

  func remove(id: String) {
    _ = locked { storage.removeValue(forKey: id) }
  }

  func findByFolder(folderId: String) -> [Podcast] {
    locked { storage.values.filter { $0.folderId == folderId } }
  }

  func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] {
    locked {
      var results = storage.values.filter { $0.folderId == folderId }
      let descendants = folderManager.getDescendants(of: folderId)
      for folder in descendants {
        results.append(contentsOf: storage.values.filter { $0.folderId == folder.id })
      }
      return results
    }
  }

  func findByTag(tagId: String) -> [Podcast] {
    locked { storage.values.filter { $0.tagIds.contains(tagId) } }
  }

  func findUnorganized() -> [Podcast] {
    locked { storage.values.filter { $0.folderId == nil && $0.tagIds.isEmpty } }
  }

  func fetchOrphanedEpisodes() -> [Episode] { [] }
  func deleteOrphanedEpisode(id: String) -> Bool { false }
  func deleteAllOrphanedEpisodes() -> Int { 0 }

  private func locked<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }
}

enum PreviewPodcastData {
  static let podcasts: [Podcast] = [
    Podcast(
      id: "swift-weekly",
      title: "Swift Weekly Podcast",
      author: "iOS Developer",
      description: "Weekly discussions about Swift programming and iOS development.",
      artworkURL: URL(string: "https://example.com/swift-weekly.png"),
      feedURL: URL(string: "https://example.com/swift-weekly.xml")!,
      categories: ["Technology", "Swift"],
      episodes: [
        Episode(
          id: "ep-001",
          title: "Getting Started with Swift 6",
          podcastID: "swift-weekly"
        ),
        Episode(
          id: "ep-002",
          title: "Building iOS Apps with SwiftUI",
          podcastID: "swift-weekly"
        )
      ],
      isSubscribed: true,
      dateAdded: Date().addingTimeInterval(-86_400),
      tagIds: ["swift", "development"]
    ),
    Podcast(
      id: "design-notes",
      title: "Design Notes",
      author: "Product Team",
      description: "Conversations about product design and UX craft.",
      artworkURL: URL(string: "https://example.com/design-notes.png"),
      feedURL: URL(string: "https://example.com/design-notes.xml")!,
      categories: ["Design"],
      episodes: [
        Episode(
          id: "dn-101",
          title: "Design Systems",
          podcastID: "design-notes"
        ),
        Episode(
          id: "dn-102",
          title: "Accessibility at Scale",
          podcastID: "design-notes"
        )
      ],
      isSubscribed: false,
      dateAdded: Date().addingTimeInterval(-172_800),
      tagIds: ["design", "ux"]
    )
  ]
}

#endif

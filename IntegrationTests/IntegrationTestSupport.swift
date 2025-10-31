import XCTest
@testable import CoreModels
@testable import TestSupport
@testable import SearchDomain
@testable import DiscoverFeature
@testable import PlaybackEngine

// This file now serves as a bridge, re-exporting test helpers from TestSupport
// and providing integration-test-specific utilities that depend on SearchDomain/DiscoverFeature.

// Re-export helpers from TestSupport for convenience
public typealias MockEpisodeStateManager = TestSupport.MockEpisodeStateManager
public typealias PlaylistManager = TestSupport.PlaylistManager
public typealias PlaylistEngine = TestSupport.PlaylistEngine

// Integration test specific helpers are now in separate files:
// - MockRSSParser.swift (depends on DiscoverFeature)
// - WorkflowTestBuilder.swift (depends on SearchDomain)
// - SearchTestBuilder.swift (depends on SearchDomain)

// MARK: - Search Index Sources (already in SearchDomain, re-exported for convenience)

public typealias PodcastIndexSource = SearchDomain.PodcastIndexSource
public typealias EpisodeIndexSource = SearchDomain.EpisodeIndexSource

// MARK: - Extensions for Testing

extension InMemoryPodcastManager {
    func findByFolderRecursive(folderId: String, folderManager: InMemoryFolderManager) -> [Podcast] {
        let directPodcasts = findByFolder(folderId: folderId)
        let childFolders = folderManager.getDescendants(of: folderId)
        let childPodcasts = childFolders.flatMap { folder in
            findByFolder(folderId: folder.id)
        }
        return directPodcasts + childPodcasts
    }
    
    func getSubscribedPodcasts() -> [Podcast] {
        return all().filter { $0.isSubscribed }
    }
}

extension Podcast {
    func withSubscriptionStatus(_ isSubscribed: Bool) -> Podcast {
        return Podcast(
            id: self.id,
            title: self.title,
            description: self.description,
            feedURL: self.feedURL,
            categories: self.categories,
            episodes: self.episodes,
            isSubscribed: isSubscribed,
            dateAdded: self.dateAdded,
            folderId: self.folderId,
            tagIds: self.tagIds
        )
    }
}

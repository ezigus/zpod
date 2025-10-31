import Foundation
import XCTest
import CoreModels
import TestSupport
import SearchDomain

/// Builder for setting up common workflow test scenarios
///
/// This builder simplifies the creation of podcast libraries, folders, and search indexes
/// for workflow integration tests. It provides a fluent API for test setup.
///
/// Example usage:
/// ```swift
/// let builder = try await WorkflowTestBuilder()
///     .withPodcastManager(podcastManager)
///     .withFolderManager(folderManager)
///     .withSearchService(searchService)
///     .addFolder(id: "tech", name: "Technology")
///     .addPodcast(id: "pod1", title: "Swift Weekly", folderId: "tech")
///     .addPodcast(id: "pod2", title: "iOS Tips")
///     .buildSearchIndex()
/// ```
@MainActor
final class WorkflowTestBuilder {
    private var podcastManager: InMemoryPodcastManager?
    private var folderManager: InMemoryFolderManager?
    private var searchService: SearchService?
    
    init() {}
    
    // MARK: - Manager Configuration
    
    /// Sets the podcast manager for this builder
    @discardableResult
    func withPodcastManager(_ manager: InMemoryPodcastManager) -> Self {
        self.podcastManager = manager
        return self
    }
    
    /// Sets the folder manager for this builder
    @discardableResult
    func withFolderManager(_ manager: InMemoryFolderManager) -> Self {
        self.folderManager = manager
        return self
    }
    
    /// Sets the search service for this builder
    @discardableResult
    func withSearchService(_ service: SearchService) -> Self {
        self.searchService = service
        return self
    }
    
    // MARK: - Data Setup
    
    /// Adds a folder to the library
    @discardableResult
    func addFolder(id: String, name: String, parentId: String? = nil) throws -> Self {
        guard let folderManager = folderManager else {
            XCTFail("Folder manager not configured")
            return self
        }
        
        let folder = Folder(id: id, name: name, parentId: parentId)
        try folderManager.add(folder)
        return self
    }
    
    /// Adds a podcast to the library
    @discardableResult
    func addPodcast(
        id: String,
        title: String,
        description: String? = nil,
        feedURL: String = "https://example.com/feed.xml",
        folderId: String? = nil,
        tagIds: [String] = [],
        isSubscribed: Bool = false
    ) -> Self {
        guard let podcastManager = podcastManager else {
            XCTFail("Podcast manager not configured")
            return self
        }
        
        let podcast = Podcast(
            id: id,
            title: title,
            description: description,
            feedURL: URL(string: feedURL)!,
            isSubscribed: isSubscribed,
            folderId: folderId,
            tagIds: tagIds
        )
        
        podcastManager.add(podcast)
        return self
    }
    
    /// Adds a podcast with episodes to the library
    @discardableResult
    func addPodcastWithEpisodes(
        id: String,
        title: String,
        description: String? = nil,
        feedURL: String = "https://example.com/feed.xml",
        folderId: String? = nil,
        tagIds: [String] = [],
        isSubscribed: Bool = false,
        episodeCount: Int = 3
    ) -> Self {
        guard let podcastManager = podcastManager else {
            XCTFail("Podcast manager not configured")
            return self
        }
        
        let episodes = (1...episodeCount).map { index in
            Episode(
                id: "\(id)-ep\(index)",
                title: "Episode \(index)",
                podcastID: id,
                playbackPosition: 0,
                isPlayed: false,
                pubDate: Date().addingTimeInterval(TimeInterval(-index * 86400)), // Each episode one day apart
                duration: 1800,
                description: "Episode \(index) of \(title)",
                audioURL: URL(string: "https://example.com/\(id)/ep\(index).mp3")
            )
        }
        
        let podcast = Podcast(
            id: id,
            title: title,
            description: description,
            feedURL: URL(string: feedURL)!,
            episodes: episodes,
            isSubscribed: isSubscribed,
            folderId: folderId,
            tagIds: tagIds
        )
        
        podcastManager.add(podcast)
        return self
    }
    
    /// Rebuilds the search index with current podcast data
    @discardableResult
    func buildSearchIndex() async -> Self {
        guard let searchService = searchService else {
            XCTFail("Search service not configured")
            return self
        }
        
        await searchService.rebuildIndex()
        return self
    }
    
    /// Updates a podcast to be subscribed
    @discardableResult
    func subscribeToPodcast(id: String) -> Self {
        guard let podcastManager = podcastManager else {
            XCTFail("Podcast manager not configured")
            return self
        }
        
        guard let podcast = podcastManager.find(id: id) else {
            XCTFail("Podcast not found: \(id)")
            return self
        }
        
        let subscribed = podcast.withSubscriptionStatus(true)
        podcastManager.update(subscribed)
        return self
    }
}

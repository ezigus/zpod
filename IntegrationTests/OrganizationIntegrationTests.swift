import XCTest
@testable import CoreModels
import TestSupport
@testable import SearchDomain

/// Integration tests for subscription and organization workflows
///
/// **Specifications Covered**: Organization and subscription workflows
/// - Complete subscription workflow from discovery to organization
/// - Multiple podcast organization in hierarchies
/// - Folder and tag management
final class OrganizationIntegrationTests: XCTestCase, @unchecked Sendable {
    
    // MARK: - Properties  
    private var podcastManager: InMemoryPodcastManager!
    private var folderManager: InMemoryFolderManager!
    private var searchService: SearchService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        podcastManager = InMemoryPodcastManager()
        folderManager = InMemoryFolderManager()

        let setupExpectation = expectation(description: "Setup main actor components")

        Task { @MainActor in
            searchService = SearchService(
                indexSources: [
                    PodcastIndexSource(podcastManager: podcastManager),
                    EpisodeIndexSource(podcastManager: podcastManager)
                ]
            )
            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: 5.0)
    }
    
    override func tearDown() {
        searchService = nil
        folderManager = nil
        podcastManager = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func rebuildSearchIndex() async {
        await searchService.rebuildIndex()
    }

    private func searchPodcasts(
        _ query: String,
        filter: SearchFilter = .podcastsOnly
    ) async -> [Podcast] {
        let results = await searchService.search(query: query, filter: filter)
        return results.compactMap { result in
            if case .podcast(let podcast, _) = result {
                return podcast
            }
            return nil
        }
    }
    
    // MARK: - Subscription and Organization Workflow Tests
    
    func testCompleteSubscriptionWorkflow() async throws {
        // Given: User discovers a podcast and wants to organize their library
        let techFolder = Folder(id: "tech", name: "Technology")
        let programmingTag = Tag(id: "programming", name: "Programming")
        
        try folderManager.add(techFolder)
        
        let discoveredPodcast = Podcast(
            id: "swift-podcast",
            title: "Swift Programming Weekly",
            description: "Weekly Swift programming tips and news",
            feedURL: URL(string: "https://example.com/swift-weekly.xml")!
        )
        
        // When: User subscribes and organizes the podcast
        // Step 1: Add podcast to library
        podcastManager.add(discoveredPodcast)
        
        // Step 2: Subscribe to podcast
        let subscribedPodcast = discoveredPodcast.withSubscriptionStatus(true)
        podcastManager.update(subscribedPodcast)
        
        // Step 3: Organize podcast in folder and with tags
        let organizedPodcast = Podcast(
            id: subscribedPodcast.id,
            title: subscribedPodcast.title,
            description: subscribedPodcast.description,
            feedURL: subscribedPodcast.feedURL,
            isSubscribed: subscribedPodcast.isSubscribed,
            folderId: "tech",
            tagIds: ["programming"]
        )
        podcastManager.update(organizedPodcast)
        
        // Step 4: Rebuild search index after organizing content
        await rebuildSearchIndex()
        
        // Then: Podcast should be fully integrated into user's library
        let finalPodcast = podcastManager.find(id: "swift-podcast")
        XCTAssertNotNil(finalPodcast)
        XCTAssertTrue(finalPodcast?.isSubscribed ?? false)
        XCTAssertEqual(finalPodcast?.folderId, "tech")
        XCTAssertTrue(finalPodcast?.tagIds.contains("programming") ?? false)
        
        // Verify organization works
        let techPodcasts = podcastManager.findByFolder(folderId: "tech")
        XCTAssertEqual(techPodcasts.count, 1)
        XCTAssertEqual(techPodcasts.first?.title, "Swift Programming Weekly")
        
        let programmingPodcasts = podcastManager.findByTag(tagId: "programming")
        XCTAssertEqual(programmingPodcasts.count, 1)
        
        // Verify search integration
        let searchResults = await searchPodcasts("Swift")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.id, "swift-podcast")
    }
    
    func testMultiplePodcastOrganizationWorkflow() async throws {
        // Given: User wants to organize multiple podcasts in a hierarchy
        let rootFolder = Folder(id: "root", name: "All Podcasts")
        let techFolder = Folder(id: "tech", name: "Technology", parentId: "root")
        let swiftFolder = Folder(id: "swift", name: "Swift", parentId: "tech")
        let newsFolder = Folder(id: "news", name: "News", parentId: "root")
        
        try folderManager.add(rootFolder)
        try folderManager.add(techFolder)
        try folderManager.add(swiftFolder)
        try folderManager.add(newsFolder)
        
        let podcasts = [
            Podcast(
                id: "swift-weekly",
                title: "Swift Weekly",
                description: "Swift programming news",
                feedURL: URL(string: "https://example.com/swift-weekly.xml")!,
                folderId: "swift",
                tagIds: ["swift", "programming"]
            ),
            Podcast(
                id: "ios-dev",
                title: "iOS Development",
                description: "iOS development tips",
                feedURL: URL(string: "https://example.com/ios-dev.xml")!,
                folderId: "tech",
                tagIds: ["ios", "programming"]
            ),
            Podcast(
                id: "tech-news",
                title: "Tech News Daily",
                description: "Daily technology news",
                feedURL: URL(string: "https://example.com/tech-news.xml")!,
                folderId: "news",
                tagIds: ["news", "technology"]
            )
        ]
        
        // When: User organizes podcasts in hierarchy
        podcasts.forEach { podcastManager.add($0) }
        await rebuildSearchIndex()
        
        // Then: Organization hierarchy should work correctly
        let swiftPodcasts = podcastManager.findByFolder(folderId: "swift")
        XCTAssertEqual(swiftPodcasts.count, 1)
        XCTAssertEqual(swiftPodcasts.first?.title, "Swift Weekly")
        
        let techPodcasts = podcastManager.findByFolder(folderId: "tech")
        XCTAssertEqual(techPodcasts.count, 1)
        XCTAssertEqual(techPodcasts.first?.title, "iOS Development")
        
        // Test recursive folder search
        let allTechPodcasts = podcastManager.findByFolderRecursive(folderId: "tech", folderManager: folderManager)
        XCTAssertEqual(allTechPodcasts.count, 2) // iOS Development + Swift Weekly
        
        let programmingPodcasts = podcastManager.findByTag(tagId: "programming")
        XCTAssertEqual(programmingPodcasts.count, 2)
        
        // Test cross-organization search
        let swiftResults = await searchPodcasts("Swift")
        let swiftFolderScoped = swiftResults.filter { $0.folderId == "swift" }
        XCTAssertEqual(swiftFolderScoped.count, 1)

        let programmingResults = await searchPodcasts("programming")
        let programmingTagged = programmingResults.filter { $0.tagIds.contains("programming") }
        XCTAssertGreaterThanOrEqual(programmingTagged.count, 1)
    }
}

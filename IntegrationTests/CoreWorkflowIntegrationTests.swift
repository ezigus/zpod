import XCTest
@testable import CoreModels
import TestSupport
@testable import SearchDomain
@testable import DiscoverFeature
@testable import PlaybackEngine

/// Tests for complete user workflows that span multiple components and services
///
/// **Specifications Covered**: Cross-specification workflows
/// - Cross-component data synchronization
/// - Complete user journey acceptance tests
///
/// Note: Domain-specific integration tests have been extracted to:
/// - SearchDiscoveryIntegrationTests (search and discovery workflows)
/// - PlaylistPlaybackIntegrationTests (playlist and playback workflows)
/// - OrganizationIntegrationTests (subscription and organization workflows)
final class CoreWorkflowIntegrationTests: XCTestCase, @unchecked Sendable {
    
    // MARK: - Properties  
    private var podcastManager: InMemoryPodcastManager!
    private var folderManager: InMemoryFolderManager!
    private var playlistManager: PlaylistManager!
    private var playlistBuilder: PlaylistTestBuilder!
    private var episodeStateManager: MockEpisodeStateManager!
    private var searchService: SearchService!
    private var workflowBuilder: WorkflowTestBuilder!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        podcastManager = InMemoryPodcastManager()
        folderManager = InMemoryFolderManager()

        let setupExpectation = expectation(description: "Setup main actor components")

        Task { @MainActor in
            let manager = PlaylistManager()
            playlistManager = manager

            let search = SearchService(
                indexSources: [
                    PodcastIndexSource(podcastManager: podcastManager),
                    EpisodeIndexSource(podcastManager: podcastManager)
                ]
            )
            searchService = search

            let builder = WorkflowTestBuilder()
            workflowBuilder = builder
            _ = builder
                .withPodcastManager(podcastManager)
                .withFolderManager(folderManager)
                .withSearchService(search)

            playlistBuilder = PlaylistTestBuilder().withPlaylistManager(manager)

            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: 5.0)
        episodeStateManager = MockEpisodeStateManager()
    }
    
    override func tearDown() {
        episodeStateManager = nil
        playlistBuilder = nil
        workflowBuilder = nil
        playlistManager = nil
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
    
    // MARK: - Cross-Component Data Consistency Tests
    // Covers: Data synchronization between components
    
    func testCrossComponentDataConsistency() async throws {
        // Given: Data that spans multiple components
        try await workflowBuilder
            .addFolder(id: "consistency-test", name: "Consistency Test")
            .addPodcast(
                id: "consistent-podcast",
                title: "Consistency Test Podcast",
                description: "Testing data consistency",
                feedURL: "https://example.com/consistent.xml",
                folderId: "consistency-test",
                tagIds: ["test", "consistency"]
            )

        let episode = Episode(
            id: "consistent-episode",
            title: "Consistency Episode",
            podcastID: "consistent-podcast",
            playbackPosition: 0,
            isPlayed: false,
            pubDate: Date(),
            duration: 1800,
            description: "Testing consistency",
            audioURL: URL(string: "https://example.com/consistent.mp3")
        )
        
        // When: Data is added across components
        _ = await workflowBuilder.buildSearchIndex()
        await episodeStateManager.updateEpisodeState(episode)

        _ = await playlistBuilder
            .addManualPlaylist(
                name: "Consistency Playlist",
                episodeIds: ["consistent-episode"]
            )
        
        // Then: Data should be consistent across all components
        
        // Verify podcast manager has correct data
        let foundPodcast = podcastManager.find(id: "consistent-podcast")
        XCTAssertNotNil(foundPodcast)
        XCTAssertEqual(foundPodcast?.folderId, "consistency-test")
        XCTAssertTrue(foundPodcast?.tagIds.contains("test") ?? false)
        
        // Verify folder manager has correct relationship
        let folderPodcasts = podcastManager.findByFolder(folderId: "consistency-test")
        XCTAssertEqual(folderPodcasts.count, 1)
        XCTAssertEqual(folderPodcasts.first?.id, "consistent-podcast")
        
        // Verify search index has correct data
        let searchResults = await searchPodcasts("Consistency")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.id, "consistent-podcast")
        
        // Verify episode state is maintained
        let episodeState = await episodeStateManager.getEpisodeState(episode)
        XCTAssertEqual(episodeState.id, "consistent-episode")
        XCTAssertEqual(episodeState.podcastID, "consistent-podcast")
        
        // Verify playlist has correct episode reference
        let playlists = await playlistManager.playlists
        XCTAssertEqual(playlists.count, 1)
        XCTAssertTrue(playlists.first?.episodeIds.contains("consistent-episode") ?? false)
    }
    
    // MARK: - Acceptance Criteria Tests
    // Covers: Complete end-to-end user workflows
    
    func testAcceptanceCriteria_CompleteUserJourney() async throws {
        // Given: New user starts using the app
        // When: User goes through complete workflow
        
        // Step 1: User discovers and subscribes to podcasts
        let discoveredPodcasts = [
            (id: "swift-weekly", title: "Swift Weekly", description: "Weekly Swift programming news", feedURL: "https://example.com/swift-weekly.xml"),
            (id: "swift-tips", title: "Swift Tips", description: "Daily Swift programming tips", feedURL: "https://example.com/swift-tips.xml")
        ]

        for podcast in discoveredPodcasts {
            await workflowBuilder.addPodcast(
                id: podcast.id,
                title: podcast.title,
                description: podcast.description,
                feedURL: podcast.feedURL
            )
        }
        _ = await workflowBuilder.buildSearchIndex()
        for podcast in discoveredPodcasts {
            _ = await workflowBuilder.subscribeToPodcast(id: podcast.id)
        }
        
        // Step 2: User organizes podcasts
        let techFolder = Folder(id: "tech", name: "Technology")
        try folderManager.add(techFolder)
        
        let organizedPodcasts: [Podcast] = discoveredPodcasts.compactMap { podcast in
            guard let existing = podcastManager.find(id: podcast.id) else { return nil }
            return existing
                .withSubscriptionStatus(true)
                .withOrganization(folderId: "tech", tagIds: ["programming", "technology"])
        }

        organizedPodcasts.forEach { podcastManager.update($0) }
        await rebuildSearchIndex()

        // Step 3: User creates playlists
        _ = await playlistBuilder
            .addManualPlaylist(
                name: "Daily Tech",
                episodeIds: ["swift-weekly-ep1", "swift-tips-ep1"],
                continuousPlayback: true,
                shuffleAllowed: true
            )
            .addSmartPlaylist(
                name: "New Tech Episodes",
                maxEpisodes: 20,
                orderBy: .dateAdded,
                filterRules: [.isPlayed(false), .podcastCategory("Technology")]
            )
        
        // Step 4: User searches and browses content
        let searchResults = await searchService.search(query: "Swift", filter: .podcastsOnly)
        let swiftPodcasts = searchResults.compactMap { result -> Podcast? in
            if case .podcast(let podcast, _) = result {
                return podcast
            }
            return nil
        }
        let techPodcasts = podcastManager.findByFolder(folderId: "tech")
        let programmingPodcasts = podcastManager.findByTag(tagId: "programming")
        
        // Then: All functionality should work together seamlessly
        
        // Verify subscription workflow
        let subscribedPodcasts = podcastManager.getSubscribedPodcasts()
        XCTAssertEqual(subscribedPodcasts.count, 2)
        XCTAssertTrue(subscribedPodcasts.allSatisfy { $0.isSubscribed })
        
        // Verify organization workflow
        XCTAssertEqual(techPodcasts.count, 2)
        XCTAssertEqual(programmingPodcasts.count, 2)
        XCTAssertTrue(techPodcasts.allSatisfy { $0.folderId == "tech" })
        XCTAssertTrue(programmingPodcasts.allSatisfy { $0.tagIds.contains("programming") })
        
        // Verify playlist workflow
        let playlists = await playlistManager.playlists
        let smartPlaylists = await playlistManager.smartPlaylists
        XCTAssertEqual(playlists.count, 1)
        XCTAssertEqual(smartPlaylists.count, 1)
        
        // Verify search workflow
        XCTAssertEqual(swiftPodcasts.count, 2)
        let swiftTitles = Set(swiftPodcasts.map(\.title))
        XCTAssertEqual(swiftTitles, Set(["Swift Weekly", "Swift Tips"]))

        // Verify data consistency across all components
        let consistencyPodcast = podcastManager.find(id: "swift-tips")
        let searchedPodcast = swiftPodcasts.first { $0.id == "swift-tips" }
        XCTAssertEqual(consistencyPodcast?.id, searchedPodcast?.id)
        XCTAssertEqual(consistencyPodcast?.folderId, searchedPodcast?.folderId)
        XCTAssertEqual(consistencyPodcast?.tagIds, searchedPodcast?.tagIds)
    }
}

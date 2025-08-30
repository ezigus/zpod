import XCTest
@testable import CoreModels
@testable import TestSupport
@testable import SearchDomain
@testable import zpodLib

/// Tests for complete user workflows that span multiple components and services
///
/// **Specifications Covered**: Cross-specification workflows
/// - Complete subscription and organization workflows (discovery + content)
/// - Playback queue management with playlist integration (content + playback)
/// - Search and content organization workflows (discovery + organization)
/// - Settings persistence across app sessions (all specifications)
/// - Cross-component data synchronization
final class CoreWorkflowIntegrationTests: XCTestCase, @unchecked Sendable {
    
    // MARK: - Properties  
    private var podcastManager: InMemoryPodcastManager!
    private var folderManager: InMemoryFolderManager!
    private var searchIndex: SearchIndex!
    private var playlistManager: PlaylistManager!
    private var episodeStateManager: MockEpisodeStateManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        podcastManager = InMemoryPodcastManager()
        folderManager = InMemoryFolderManager()
        searchIndex = SearchIndex()
        playlistManager = PlaylistManager()
        episodeStateManager = MockEpisodeStateManager()
    }
    
    override func tearDown() {
        episodeStateManager = nil
        playlistManager = nil
        searchIndex = nil
        folderManager = nil
        podcastManager = nil
        super.tearDown()
    }
    
    // MARK: - Subscription and Organization Workflow Tests
    // Covers: Complete user journey from discovery to organized library
    
    func testCompleteSubscriptionWorkflow() throws {
        // Given: User discovers a podcast and wants to organize their library
        let techFolder = Folder(id: "tech", name: "Technology")
        let programmingTag = Tag(id: "programming", name: "Programming", color: "#007ACC")
        
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
        
        // Step 4: Index for search
        searchIndex.indexPodcast(organizedPodcast)
        
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
        let searchResults = searchIndex.searchPodcasts(query: "Swift")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.id, "swift-podcast")
    }
    
    func testMultiplePodcastOrganizationWorkflow() throws {
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
        podcasts.forEach { podcast in
            podcastManager.add(podcast)
            searchIndex.indexPodcast(podcast)
        }
        
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
        let swiftResults = searchIndex.searchPodcasts(query: "Swift")
        XCTAssertEqual(swiftResults.count, 1)
        
        let programmingResults = searchIndex.searchPodcasts(query: "programming")
        XCTAssertGreaterThanOrEqual(programmingResults.count, 1)
    }
    
    // MARK: - Playlist and Playback Integration Tests
    // Covers: Playlist creation and playback queue workflows
    
    func testPlaylistCreationAndPlaybackWorkflow() async throws {
        // Given: User has podcasts and episodes and wants to create playlists
        let podcast1 = Podcast(
            id: "podcast1",
            title: "Tech Talk",
            feedURL: URL(string: "https://example.com/tech.xml")!
        )
        
        let podcast2 = Podcast(
            id: "podcast2",
            title: "Science Weekly",
            feedURL: URL(string: "https://example.com/science.xml")!
        )
        
        let episodes = [
            Episode(
                id: "ep1",
                title: "Latest Tech Trends",
                podcastID: "podcast1",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: Date(),
                duration: 1800,
                description: "Discussion of latest tech trends",
                audioURL: URL(string: "https://example.com/ep1.mp3")
            ),
            Episode(
                id: "ep2",
                title: "Science News",
                podcastID: "podcast2",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: Date(),
                duration: 2400,
                description: "Weekly science news roundup",
                audioURL: URL(string: "https://example.com/ep2.mp3")
            ),
            Episode(
                id: "ep3",
                title: "Programming Tips",
                podcastID: "podcast1",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: Date(),
                duration: 1500,
                description: "Useful programming tips",
                audioURL: URL(string: "https://example.com/ep3.mp3")
            )
        ]
        
        podcastManager.add(podcast1)
        podcastManager.add(podcast2)
        
        // When: User creates manual and smart playlists
        // Create manual playlist
        let manualPlaylist = Playlist(
            name: "My Favorites",
            episodeIds: ["ep1", "ep3"],
            continuousPlayback: true,
            shuffleAllowed: true
        )
        await playlistManager.createPlaylist(manualPlaylist)
        
        // Create smart playlist for unplayed episodes
        let smartCriteria = SmartPlaylistCriteria(
            maxEpisodes: 10,
            orderBy: .dateAdded,
            filterRules: [.isPlayed(false)]
        )
        let smartPlaylist = SmartPlaylist(
            name: "Unplayed Episodes",
            criteria: smartCriteria
        )
        await playlistManager.createSmartPlaylist(smartPlaylist)
        
        // Then: Playlists should be created and functional
        let createdPlaylists = await playlistManager.playlists
        XCTAssertEqual(createdPlaylists.count, 1)
        XCTAssertEqual(createdPlaylists.first?.name, "My Favorites")
        
        let createdSmartPlaylists = await playlistManager.smartPlaylists
        XCTAssertEqual(createdSmartPlaylists.count, 1)
        XCTAssertEqual(createdSmartPlaylists.first?.name, "Unplayed Episodes")
        
        // Test playlist functionality with playback engine
        let playlistEngine = PlaylistEngine()
        let queue = await playlistEngine.generatePlaybackQueue(
            from: manualPlaylist,
            episodes: episodes
        )
        
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue[0].id, "ep1")
        XCTAssertEqual(queue[1].id, "ep3")
        
        // Test smart playlist evaluation
        let downloadStatuses: [String: DownloadState] = ["ep1": .completed, "ep2": .completed, "ep3": .completed]
        let smartResults = await playlistEngine.evaluateSmartPlaylist(
            smartPlaylist,
            episodes: episodes,
            downloadStatuses: downloadStatuses
        )
        
        XCTAssertEqual(smartResults.count, 3) // All episodes are unplayed
    }
    
    // MARK: - Search and Content Discovery Integration Tests
    // Covers: Search integration with organized content
    
    func testSearchAndDiscoveryIntegration() throws {
        // Given: User has organized library and wants to search across it
        let folders = [
            Folder(id: "tech", name: "Technology"),
            Folder(id: "entertainment", name: "Entertainment")
        ]
        
        folders.forEach { try? folderManager.add($0) }
        
        let podcasts = [
            Podcast(
                id: "swift-pod",
                title: "Swift Programming Guide",
                description: "Learn Swift programming from experts",
                feedURL: URL(string: "https://example.com/swift.xml")!,
                folderId: "tech",
                tagIds: ["swift", "programming", "education"]
            ),
            Podcast(
                id: "comedy-pod",
                title: "Comedy Hour",
                description: "Weekly comedy show",
                feedURL: URL(string: "https://example.com/comedy.xml")!,
                folderId: "entertainment",
                tagIds: ["comedy", "entertainment"]
            ),
            Podcast(
                id: "swift-music",
                title: "Taylor Swift Music Review",
                description: "Reviews of Taylor Swift albums",
                feedURL: URL(string: "https://example.com/swift-music.xml")!,
                folderId: "entertainment",
                tagIds: ["music", "entertainment"]
            )
        ]
        
        // When: User builds library and searches
        podcasts.forEach { podcast in
            podcastManager.add(podcast)
            searchIndex.indexPodcast(podcast)
        }
        
        // Then: Search should work across different organization dimensions
        
        // General search
        let swiftResults = searchIndex.searchPodcasts(query: "Swift")
        XCTAssertEqual(swiftResults.count, 2) // Programming guide + music review
        
        // Folder-scoped search
        let techSwiftResults = searchIndex.searchPodcasts(query: "Swift", folderId: "tech")
        XCTAssertEqual(techSwiftResults.count, 1)
        XCTAssertEqual(techSwiftResults.first?.title, "Swift Programming Guide")
        
        let entertainmentSwiftResults = searchIndex.searchPodcasts(query: "Swift", folderId: "entertainment")
        XCTAssertEqual(entertainmentSwiftResults.count, 1)
        XCTAssertEqual(entertainmentSwiftResults.first?.title, "Taylor Swift Music Review")
        
        // Tag-scoped search
        let programmingResults = searchIndex.searchPodcasts(query: "programming", tagId: "programming")
        XCTAssertEqual(programmingResults.count, 1)
        XCTAssertEqual(programmingResults.first?.title, "Swift Programming Guide")
        
        // Cross-organization filtering
        let techPodcasts = podcastManager.findByFolder(folderId: "tech")
        let programmingPodcasts = podcastManager.findByTag(tagId: "programming")
        let educationPodcasts = podcastManager.findByTag(tagId: "education")
        
        XCTAssertEqual(techPodcasts.count, 1)
        XCTAssertEqual(programmingPodcasts.count, 1)
        XCTAssertEqual(educationPodcasts.count, 1)
        
        // All should reference the same podcast
        XCTAssertEqual(techPodcasts.first?.id, programmingPodcasts.first?.id)
        XCTAssertEqual(programmingPodcasts.first?.id, educationPodcasts.first?.id)
    }
    
    // MARK: - Episode State and Playback Integration Tests  
    // Covers: Episode state management across playback and organization
    
    func testEpisodeStateManagementIntegration() async throws {
        // Given: User has episodes in various states across playlists
        let podcast = Podcast(
            id: "test-podcast",
            title: "Test Podcast",
            feedURL: URL(string: "https://example.com/test.xml")!
        )
        
        let episodes = [
            Episode(
                id: "ep1",
                title: "Episode 1",
                podcastID: "test-podcast",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: Date(),
                duration: 1800,
                description: "First episode",
                audioURL: URL(string: "https://example.com/ep1.mp3")
            ),
            Episode(
                id: "ep2",
                title: "Episode 2",
                podcastID: "test-podcast",
                playbackPosition: 900,
                isPlayed: false,
                pubDate: Date(),
                duration: 1800,
                description: "Second episode",
                audioURL: URL(string: "https://example.com/ep2.mp3")
            ),
            Episode(
                id: "ep3",
                title: "Episode 3",
                podcastID: "test-podcast",
                playbackPosition: 1800,
                isPlayed: true,
                pubDate: Date(),
                duration: 1800,
                description: "Third episode",
                audioURL: URL(string: "https://example.com/ep3.mp3")
            )
        ]
        
        podcastManager.add(podcast)
        
        // When: User creates playlists based on episode states
        let unplayedPlaylist = SmartPlaylist(
            name: "Unplayed",
            criteria: SmartPlaylistCriteria(
                maxEpisodes: 10,
                orderBy: .dateAdded,
                filterRules: [.isPlayed(false)]
            )
        )
        
        let inProgressPlaylist = SmartPlaylist(
            name: "In Progress",
            criteria: SmartPlaylistCriteria(
                maxEpisodes: 10,
                orderBy: .dateAdded,
                filterRules: [.isPlayed(false)] // Episodes with progress but not marked as played
            )
        )
        
        await playlistManager.createSmartPlaylist(unplayedPlaylist)
        await playlistManager.createSmartPlaylist(inProgressPlaylist)
        
        // Simulate episode state changes
        for episode in episodes {
            await episodeStateManager.updateEpisodeState(episode)
        }
        
        // Then: Smart playlists should reflect episode states
        let playlistEngine = PlaylistEngine()
        let downloadStatuses: [String: DownloadState] = [
            "ep1": .completed,
            "ep2": .completed,
            "ep3": .completed
        ]
        
        let unplayedResults = await playlistEngine.evaluateSmartPlaylist(
            unplayedPlaylist,
            episodes: episodes,
            downloadStatuses: downloadStatuses
        )
        
        XCTAssertEqual(unplayedResults.count, 2) // ep1 and ep2 are not marked as played
        XCTAssertTrue(unplayedResults.contains { $0.id == "ep1" })
        XCTAssertTrue(unplayedResults.contains { $0.id == "ep2" })
        XCTAssertFalse(unplayedResults.contains { $0.id == "ep3" })
        
        // Test episode state persistence
        let retrievedEp2 = await episodeStateManager.getEpisodeState(episodes[1])
        XCTAssertEqual(retrievedEp2.playbackPosition, 900)
        XCTAssertFalse(retrievedEp2.isPlayed)
        
        let retrievedEp3 = await episodeStateManager.getEpisodeState(episodes[2])
        XCTAssertTrue(retrievedEp3.isPlayed)
    }
    
    // MARK: - Cross-Component Data Consistency Tests
    // Covers: Data synchronization between components
    
    func testCrossComponentDataConsistency() async throws {
        // Given: Data that spans multiple components
        let folder = Folder(id: "consistency-test", name: "Consistency Test")
        try folderManager.add(folder)
        
        let podcast = Podcast(
            id: "consistent-podcast",
            title: "Consistency Test Podcast",
            description: "Testing data consistency",
            feedURL: URL(string: "https://example.com/consistent.xml")!,
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
        podcastManager.add(podcast)
        searchIndex.indexPodcast(podcast)
        await episodeStateManager.updateEpisodeState(episode)
        
        let playlist = Playlist(
            name: "Consistency Playlist",
            episodeIds: ["consistent-episode"]
        )
        await playlistManager.createPlaylist(playlist)
        
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
        let searchResults = searchIndex.searchPodcasts(query: "Consistency")
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
            Podcast(
                id: "tech-weekly",
                title: "Tech Weekly",
                description: "Weekly technology news",
                feedURL: URL(string: "https://example.com/tech-weekly.xml")!
            ),
            Podcast(
                id: "swift-tips",
                title: "Swift Tips",
                description: "Daily Swift programming tips",
                feedURL: URL(string: "https://example.com/swift-tips.xml")!
            )
        ]
        
        discoveredPodcasts.forEach { podcast in
            podcastManager.add(podcast)
            let subscribed = podcast.withSubscriptionStatus(true)
            podcastManager.update(subscribed)
            searchIndex.indexPodcast(subscribed)
        }
        
        // Step 2: User organizes podcasts
        let techFolder = Folder(id: "tech", name: "Technology")
        try folderManager.add(techFolder)
        
        let organizedPodcasts = discoveredPodcasts.map { podcast in
            Podcast(
                id: podcast.id,
                title: podcast.title,
                description: podcast.description,
                feedURL: podcast.feedURL,
                isSubscribed: true,
                folderId: "tech",
                tagIds: ["programming", "technology"]
            )
        }
        
        organizedPodcasts.forEach { podcast in
            podcastManager.update(podcast)
            searchIndex.indexPodcast(podcast)
        }
        
        // Step 3: User creates playlists
        let favoritePlaylist = Playlist(
            name: "Daily Tech",
            episodeIds: [],
            continuousPlayback: true
        )
        await playlistManager.createPlaylist(favoritePlaylist)
        
        let smartPlaylist = SmartPlaylist(
            name: "New Tech Episodes",
            criteria: SmartPlaylistCriteria(
                maxEpisodes: 20,
                orderBy: .dateAdded,
                filterRules: [.isPlayed(false), .podcastCategory("Technology")]
            )
        )
        await playlistManager.createSmartPlaylist(smartPlaylist)
        
        // Step 4: User searches and browses content
        let searchResults = searchIndex.searchPodcasts(query: "Swift")
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
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.title, "Swift Tips")
        
        // Verify data consistency across all components
        let consistencyPodcast = podcastManager.find(id: "swift-tips")
        let searchedPodcast = searchResults.first
        XCTAssertEqual(consistencyPodcast?.id, searchedPodcast?.id)
        XCTAssertEqual(consistencyPodcast?.folderId, searchedPodcast?.folderId)
        XCTAssertEqual(consistencyPodcast?.tagIds, searchedPodcast?.tagIds)
    }
}

// MARK: - Test Support Classes
final class MockEpisodeStateManager: EpisodeStateManager, @unchecked Sendable {
    private let lock = NSLock()
    private var _episodes: [String: Episode] = [:]
    
    func updateEpisodeState(_ episode: Episode) async {
        lock.lock()
        defer { lock.unlock() }
        _episodes[episode.id] = episode
    }
    
    func getEpisodeState(_ episode: Episode) async -> Episode {
        lock.lock()
        defer { lock.unlock() }
        return _episodes[episode.id] ?? episode
    }
}

@MainActor
final class PlaylistManager: ObservableObject {
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var smartPlaylists: [SmartPlaylist] = []
    
    func createPlaylist(_ playlist: Playlist) async {
        playlists.append(playlist)
    }
    
    func createSmartPlaylist(_ smartPlaylist: SmartPlaylist) async {
        smartPlaylists.append(smartPlaylist)
    }
}

final class PlaylistEngine: @unchecked Sendable {
    func evaluateSmartPlaylist(
        _ smartPlaylist: SmartPlaylist,
        episodes: [Episode],
        downloadStatuses: [String: DownloadState]
    ) async -> [Episode] {
        var matchingEpisodes = episodes
        
        for filterRule in smartPlaylist.criteria.filterRules {
            matchingEpisodes = matchingEpisodes.filter { episode in
                matchesFilterRule(filterRule, episode: episode, downloadStatus: downloadStatuses[episode.id])
            }
        }
        
        if matchingEpisodes.count > smartPlaylist.criteria.maxEpisodes {
            matchingEpisodes = Array(matchingEpisodes.prefix(smartPlaylist.criteria.maxEpisodes))
        }
        
        return matchingEpisodes
    }
    
    func generatePlaybackQueue(
        from playlist: Playlist,
        episodes: [Episode],
        shuffle: Bool = false
    ) async -> [Episode] {
        let matchingEpisodes = episodes.filter { episode in
            playlist.episodeIds.contains(episode.id)
        }
        
        if !shuffle || !playlist.shuffleAllowed {
            return playlist.episodeIds.compactMap { episodeId in
                matchingEpisodes.first { $0.id == episodeId }
            }
        } else {
            return matchingEpisodes.shuffled()
        }
    }
    
    private func matchesFilterRule(_ rule: SmartPlaylistFilterRule, episode: Episode, downloadStatus: DownloadState?) -> Bool {
        switch rule {
        case .isPlayed(let isPlayed):
            return episode.isPlayed == isPlayed
        case .isDownloaded:
            return downloadStatus == .completed
        case .podcastCategory(_):
            return true // For testing purposes
        case .dateRange(let start, let end):
            guard let pubDate = episode.pubDate else { return false }
            return pubDate >= start && pubDate <= end
        case .durationRange(let min, let max):
            guard let duration = episode.duration else { return false }
            return duration >= min && duration <= max
        }
    }
}

// MARK: - Extensions for Testing
extension SearchIndex {
    func searchPodcasts(query: String, folderId: String? = nil) -> [Podcast] {
        let allResults = searchPodcasts(query: query)
        
        if let folderId = folderId {
            return allResults.filter { $0.folderId == folderId }
        }
        
        return allResults
    }
    
    func searchPodcasts(query: String, tagId: String? = nil) -> [Podcast] {
        let allResults = searchPodcasts(query: query)
        
        if let tagId = tagId {
            return allResults.filter { $0.tagIds.contains(tagId) }
        }
        
        return allResults
    }
}

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
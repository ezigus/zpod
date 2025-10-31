import XCTest
@testable import TestSupport
@testable import CoreModels

/// Tests for consolidated test helpers in TestSupport
final class ConsolidatedHelpersTests: XCTestCase {
    
    // MARK: - MockEpisodeStateManager Tests
    
    func testMockEpisodeStateManager_SetPlayedStatus() async throws {
        // Given
        let manager = MockEpisodeStateManager()
        let episode = Episode(
            id: "test-ep",
            title: "Test Episode",
            playbackPosition: 0,
            isPlayed: false
        )
        
        // When
        await manager.setPlayedStatus(episode, isPlayed: true)
        let state = await manager.getEpisodeState(episode)
        
        // Then
        XCTAssertTrue(state.isPlayed)
        XCTAssertEqual(state.id, episode.id)
    }
    
    func testMockEpisodeStateManager_UpdatePlaybackPosition() async throws {
        // Given
        let manager = MockEpisodeStateManager()
        let episode = Episode(
            id: "test-ep",
            title: "Test Episode",
            playbackPosition: 0,
            isPlayed: false
        )
        
        // When
        await manager.updatePlaybackPosition(episode, position: 120.0)
        let state = await manager.getEpisodeState(episode)
        
        // Then
        XCTAssertEqual(state.playbackPosition, 120)
    }
    
    // MARK: - PlaylistManager Tests
    
    @MainActor
    func testPlaylistManager_CreatePlaylist() async throws {
        // Given
        let manager = PlaylistManager()
        let playlist = Playlist(name: "Test Playlist", episodeIds: ["ep1", "ep2"])
        
        // When
        await manager.createPlaylist(playlist)
        
        // Then
        XCTAssertEqual(manager.playlists.count, 1)
        XCTAssertEqual(manager.playlists.first?.name, "Test Playlist")
    }
    
    @MainActor
    func testPlaylistManager_CreateSmartPlaylist() async throws {
        // Given
        let manager = PlaylistManager()
        let criteria = SmartPlaylistCriteria(
            maxEpisodes: 20,
            orderBy: .dateAdded,
            filterRules: [.isPlayed(false)]
        )
        let smartPlaylist = SmartPlaylist(name: "Unplayed", criteria: criteria)
        
        // When
        await manager.createSmartPlaylist(smartPlaylist)
        
        // Then
        XCTAssertEqual(manager.smartPlaylists.count, 1)
        XCTAssertEqual(manager.smartPlaylists.first?.name, "Unplayed")
    }
    
    // MARK: - PlaylistEngine Tests
    
    func testPlaylistEngine_EvaluateSmartPlaylist() async throws {
        // Given
        let engine = PlaylistEngine()
        let episodes = [
            Episode(id: "ep1", title: "Episode 1", isPlayed: false),
            Episode(id: "ep2", title: "Episode 2", isPlayed: true),
            Episode(id: "ep3", title: "Episode 3", isPlayed: false)
        ]
        
        let criteria = SmartPlaylistCriteria(
            maxEpisodes: 10,
            orderBy: .dateAdded,
            filterRules: [.isPlayed(false)]
        )
        let smartPlaylist = SmartPlaylist(name: "Unplayed", criteria: criteria)
        
        // When
        let result = await engine.evaluateSmartPlaylist(
            smartPlaylist,
            episodes: episodes,
            downloadStatuses: [:]
        )
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { !$0.isPlayed })
    }
    
    func testPlaylistEngine_GeneratePlaybackQueue() async throws {
        // Given
        let engine = PlaylistEngine()
        let episodes = [
            Episode(id: "ep1", title: "Episode 1"),
            Episode(id: "ep2", title: "Episode 2"),
            Episode(id: "ep3", title: "Episode 3")
        ]
        let playlist = Playlist(name: "Test", episodeIds: ["ep2", "ep1"])
        
        // When
        let queue = await engine.generatePlaybackQueue(
            from: playlist,
            episodes: episodes,
            shuffle: false
        )
        
        // Then
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue[0].id, "ep2")
        XCTAssertEqual(queue[1].id, "ep1")
    }
    
    // MARK: - PlaylistTestBuilder Tests
    
    @MainActor
    func testPlaylistTestBuilder_AddManualPlaylist() async throws {
        // Given
        let manager = PlaylistManager()
        let builder = PlaylistTestBuilder()
        
        // When
        _ = await builder
            .withPlaylistManager(manager)
            .addManualPlaylist(name: "Favorites", episodeIds: ["ep1", "ep2"])
        
        // Then
        XCTAssertEqual(manager.playlists.count, 1)
        XCTAssertEqual(manager.playlists.first?.name, "Favorites")
        XCTAssertEqual(manager.playlists.first?.episodeIds, ["ep1", "ep2"])
    }
    
    @MainActor
    func testPlaylistTestBuilder_AddUnplayedSmartPlaylist() async throws {
        // Given
        let manager = PlaylistManager()
        let builder = PlaylistTestBuilder()
        
        // When
        _ = await builder
            .withPlaylistManager(manager)
            .addUnplayedSmartPlaylist(maxEpisodes: 20)
        
        // Then
        XCTAssertEqual(manager.smartPlaylists.count, 1)
        XCTAssertEqual(manager.smartPlaylists.first?.name, "Unplayed")
        XCTAssertEqual(manager.smartPlaylists.first?.criteria.maxEpisodes, 20)
    }
    
    // MARK: - Test Extensions
    
    func testPodcast_WithSubscriptionStatus() {
        // Given
        let podcast = Podcast(
            id: "test",
            title: "Test Podcast",
            feedURL: URL(string: "https://example.com/feed.xml")!,
            isSubscribed: false
        )
        
        // When
        let subscribed = podcast.withSubscriptionStatus(true)
        
        // Then
        XCTAssertTrue(subscribed.isSubscribed)
        XCTAssertEqual(subscribed.id, podcast.id)
        XCTAssertEqual(subscribed.title, podcast.title)
    }
    
    func testInMemoryPodcastManager_GetSubscribedPodcasts() {
        // Given
        let manager = InMemoryPodcastManager()
        let podcast1 = Podcast(
            id: "pod1",
            title: "Podcast 1",
            feedURL: URL(string: "https://example.com/feed1.xml")!,
            isSubscribed: true
        )
        let podcast2 = Podcast(
            id: "pod2",
            title: "Podcast 2",
            feedURL: URL(string: "https://example.com/feed2.xml")!,
            isSubscribed: false
        )
        
        manager.add(podcast1)
        manager.add(podcast2)
        
        // When
        let subscribed = manager.getSubscribedPodcasts()
        
        // Then
        XCTAssertEqual(subscribed.count, 1)
        XCTAssertEqual(subscribed.first?.id, "pod1")
    }
}

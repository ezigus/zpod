import XCTest
@testable import CoreModels
import TestSupport
@testable import PlaybackEngine

/// Integration tests for playlist creation and playback workflows
///
/// **Specifications Covered**: Playlist and playback integration
/// - Playlist creation and playback queue workflows
/// - Manual and smart playlist functionality
/// - Episode state management with playback
final class PlaylistPlaybackIntegrationTests: XCTestCase, @unchecked Sendable {
    
    // MARK: - Properties  
    private var podcastManager: InMemoryPodcastManager!
    private var playlistManager: PlaylistManager!
    private var playlistBuilder: PlaylistTestBuilder!
    private var episodeStateManager: MockEpisodeStateManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        podcastManager = InMemoryPodcastManager()

        let setupExpectation = expectation(description: "Setup main actor components")

        Task { @MainActor in
            let manager = PlaylistManager()
            playlistManager = manager
            playlistBuilder = PlaylistTestBuilder().withPlaylistManager(manager)
            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: 5.0)
        episodeStateManager = MockEpisodeStateManager()
    }

    override func tearDown() {
        episodeStateManager = nil
        playlistBuilder = nil
        playlistManager = nil
        podcastManager = nil
        super.tearDown()
    }
    
    // MARK: - Playlist and Playback Integration Tests
    
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
        
        // When: User creates manual and smart playlists via builder
        _ = await playlistBuilder
            .addManualPlaylist(
                name: "My Favorites",
                episodeIds: ["ep1", "ep3"],
                continuousPlayback: true,
                shuffleAllowed: true
            )
            .addSmartPlaylist(
                name: "Unplayed Episodes",
                maxEpisodes: 10,
                orderBy: .dateAdded,
                filterRules: [.isPlayed(false)]
            )

        // Then: Playlists should be created and functional
        let createdPlaylists = await playlistManager.playlists
        XCTAssertEqual(createdPlaylists.count, 1)
        guard let manualPlaylist = createdPlaylists.first(where: { $0.name == "My Favorites" }) else {
            XCTFail("Manual playlist not found")
            return
        }

        let createdSmartPlaylists = await playlistManager.smartPlaylists
        XCTAssertEqual(createdSmartPlaylists.count, 1)
        guard let smartPlaylist = createdSmartPlaylists.first(where: { $0.name == "Unplayed Episodes" }) else {
            XCTFail("Smart playlist not found")
            return
        }

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
    
    // MARK: - Episode State and Playback Integration Tests  
    
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
        _ = await playlistBuilder
            .addSmartPlaylist(
                name: "Unplayed",
                maxEpisodes: 10,
                orderBy: .dateAdded,
                filterRules: [.isPlayed(false)]
            )
            .addSmartPlaylist(
                name: "In Progress",
                maxEpisodes: 10,
                orderBy: .dateAdded,
                filterRules: [.isPlayed(false)]
            )

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
        
        let smartPlaylists = await playlistManager.smartPlaylists
        guard let unplayedPlaylist = smartPlaylists.first(where: { $0.name == "Unplayed" }) else {
            XCTFail("Unplayed smart playlist not found")
            return
        }

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
}

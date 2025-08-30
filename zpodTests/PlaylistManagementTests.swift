import XCTest
#if canImport(Combine)
@preconcurrency import Combine
#endif
@testable import zpodLib

/// Tests for playlist management functionality including manual and smart playlists
///
/// **Specifications Covered**: `spec/content.md` - Playlist management sections
/// - Creating and managing manual playlists
/// - Smart playlist criteria and filtering
/// - Playlist playback queue generation
/// - Continuous playback and shuffle functionality
final class PlaylistManagementTests: XCTestCase {
    
    // MARK: - Test Fixtures
    private var sampleEpisodes: [Episode]!
    private var downloadStatuses: [String: DownloadState]!
    private var playlistEngine: PlaylistEngine!
    private var playlistManager: PlaylistManager!
    #if canImport(Combine)
    private var cancellables: Set<AnyCancellable>!
    #endif
    
    override func setUp() {
        super.setUp()
        
        // Create sample episodes for testing
        let now = Date()
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        
        sampleEpisodes = [
            Episode(
                id: "ep1",
                title: "Recent Tech News",
                podcastID: "tech-podcast",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: now,
                duration: 1800,
                description: "Latest tech updates",
                audioURL: URL(string: "https://example.com/ep1.mp3")
            ),
            Episode(
                id: "ep2",
                title: "Science Weekly",
                podcastID: "science-podcast",
                playbackPosition: 900,
                isPlayed: false,
                pubDate: oneWeekAgo,
                duration: 2400,
                description: "Weekly science roundup",
                audioURL: URL(string: "https://example.com/ep2.mp3")
            ),
            Episode(
                id: "ep3",
                title: "History Deep Dive",
                podcastID: "history-podcast",
                playbackPosition: 0,
                isPlayed: true,
                pubDate: twoWeeksAgo,
                duration: 3600,
                description: "Historical analysis",
                audioURL: URL(string: "https://example.com/ep3.mp3")
            )
        ]
        
        downloadStatuses = [
            "ep1": .completed,
            "ep2": .inProgress,
            "ep3": .completed
        ]
        
        playlistEngine = PlaylistEngine()
        playlistManager = PlaylistManager()
        
        #if canImport(Combine)
        cancellables = Set<AnyCancellable>()
        #endif
    }
    
    override func tearDown() {
        #if canImport(Combine)
        cancellables = nil
        #endif
        sampleEpisodes = nil
        downloadStatuses = nil
        playlistEngine = nil
        playlistManager = nil
        super.tearDown()
    }
    
    // MARK: - Manual Playlist Model Tests
    // Covers: Basic playlist creation and management from content spec
    
    func testPlaylistInitialization() {
        // Given: Valid playlist parameters
        // When: Creating a new playlist
        let playlist = Playlist(name: "Test Playlist")
        
        // Then: Playlist should be properly initialized
        XCTAssertEqual(playlist.name, "Test Playlist")
        XCTAssertTrue(playlist.episodeIds.isEmpty)
        XCTAssertTrue(playlist.continuousPlayback)
        XCTAssertTrue(playlist.shuffleAllowed)
        XCTAssertFalse(playlist.id.isEmpty)
    }
    
    func testPlaylistWithEpisodes() {
        // Given: A playlist and episode IDs
        let playlist = Playlist(name: "Test Playlist")
        
        // When: Adding episodes to playlist
        let updatedPlaylist = playlist.withEpisodes(["ep1", "ep2"])
        
        // Then: Episodes should be added correctly
        XCTAssertEqual(updatedPlaylist.episodeIds, ["ep1", "ep2"])
        XCTAssertEqual(updatedPlaylist.name, playlist.name)
        XCTAssertEqual(updatedPlaylist.id, playlist.id)
    }
    
    func testPlaylistCodable() throws {
        // Given: A playlist with episodes
        let playlist = Playlist(
            name: "Codable Test",
            episodeIds: ["ep1", "ep2", "ep3"],
            continuousPlayback: false,
            shuffleAllowed: false
        )
        
        // When: Encoding and decoding
        let data = try JSONEncoder().encode(playlist)
        let decoded = try JSONDecoder().decode(Playlist.self, from: data)
        
        // Then: Playlist should be preserved
        XCTAssertEqual(playlist.id, decoded.id)
        XCTAssertEqual(playlist.name, decoded.name)
        XCTAssertEqual(playlist.episodeIds, decoded.episodeIds)
        XCTAssertEqual(playlist.continuousPlayback, decoded.continuousPlayback)
        XCTAssertEqual(playlist.shuffleAllowed, decoded.shuffleAllowed)
    }
    
    // MARK: - Smart Playlist Model Tests
    // Covers: Smart playlist creation and criteria from content spec
    
    func testSmartPlaylistInitialization() {
        // Given: Smart playlist criteria
        let criteria = SmartPlaylistCriteria(
            maxEpisodes: 25,
            orderBy: .dateAdded,
            filterRules: [.isPlayed(false)]
        )
        
        // When: Creating smart playlist
        let smartPlaylist = SmartPlaylist(name: "Smart Test", criteria: criteria)
        
        // Then: Smart playlist should be properly initialized
        XCTAssertEqual(smartPlaylist.name, "Smart Test")
        XCTAssertEqual(smartPlaylist.criteria.maxEpisodes, 25)
        XCTAssertEqual(smartPlaylist.criteria.orderBy, .dateAdded)
        XCTAssertTrue(smartPlaylist.episodeIds.isEmpty) // Smart playlists populate dynamically
    }
    
    func testSmartPlaylistMaxEpisodesValidation() {
        // Given: Smart playlist criteria with invalid max episodes
        let criteria = SmartPlaylistCriteria(
            maxEpisodes: -5, // Invalid value
            orderBy: .dateAdded,
            filterRules: []
        )
        
        // When: Creating smart playlist
        let smartPlaylist = SmartPlaylist(name: "Validation Test", criteria: criteria)
        
        // Then: Max episodes should be clamped to valid range
        XCTAssertGreaterThanOrEqual(smartPlaylist.criteria.maxEpisodes, 1)
    }
    
    func testSmartPlaylistCodable() throws {
        // Given: A smart playlist with criteria
        let criteria = SmartPlaylistCriteria(
            maxEpisodes: 50,
            orderBy: .publicationDate,
            filterRules: [
                .isPlayed(false),
                .podcastCategory("Technology")
            ]
        )
        let smartPlaylist = SmartPlaylist(name: "Codable Smart", criteria: criteria)
        
        // When: Encoding and decoding
        let data = try JSONEncoder().encode(smartPlaylist)
        let decoded = try JSONDecoder().decode(SmartPlaylist.self, from: data)
        
        // Then: Smart playlist should be preserved
        XCTAssertEqual(smartPlaylist.id, decoded.id)
        XCTAssertEqual(smartPlaylist.name, decoded.name)
        XCTAssertEqual(smartPlaylist.criteria.maxEpisodes, decoded.criteria.maxEpisodes)
        XCTAssertEqual(smartPlaylist.criteria.orderBy, decoded.criteria.orderBy)
        XCTAssertEqual(smartPlaylist.criteria.filterRules.count, decoded.criteria.filterRules.count)
    }
    
    // MARK: - Playlist Queue Generation Tests
    // Covers: Playback queue generation and shuffle functionality from content spec
    
    func testManualPlaylistQueueGeneration() async {
        // Given: Manual playlist with specific episode order
        let playlist = Playlist(
            name: "Ordered Playlist",
            episodeIds: ["ep3", "ep1", "ep2"]
        )
        
        // When: Generating playback queue
        let queue = await playlistEngine.generatePlaybackQueue(
            from: playlist,
            episodes: sampleEpisodes
        )
        
        // Then: Queue should maintain playlist order
        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(queue[0].id, "ep3")
        XCTAssertEqual(queue[1].id, "ep1")
        XCTAssertEqual(queue[2].id, "ep2")
    }
    
    func testManualPlaylistQueueWithShuffle() async {
        // Given: Manual playlist that allows shuffle
        let playlist = Playlist(
            name: "Shuffleable Playlist",
            episodeIds: ["ep1", "ep2", "ep3"],
            shuffleAllowed: true
        )
        
        // When: Generating shuffled queue
        let queue = await playlistEngine.generatePlaybackQueue(
            from: playlist,
            episodes: sampleEpisodes,
            shuffle: true
        )
        
        // Then: Queue should contain all episodes (order may vary due to shuffle)
        XCTAssertEqual(queue.count, 3)
        XCTAssertTrue(queue.contains { $0.id == "ep1" })
        XCTAssertTrue(queue.contains { $0.id == "ep2" })
        XCTAssertTrue(queue.contains { $0.id == "ep3" })
    }
    
    func testManualPlaylistQueueShuffleNotAllowed() async {
        // Given: Manual playlist that doesn't allow shuffle
        let playlist = Playlist(
            name: "Non-Shuffleable Playlist",
            episodeIds: ["ep1", "ep2", "ep3"],
            shuffleAllowed: false
        )
        
        // When: Attempting to generate shuffled queue
        let queue = await playlistEngine.generatePlaybackQueue(
            from: playlist,
            episodes: sampleEpisodes,
            shuffle: true
        )
        
        // Then: Queue should maintain original order despite shuffle request
        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(queue[0].id, "ep1")
        XCTAssertEqual(queue[1].id, "ep2")
        XCTAssertEqual(queue[2].id, "ep3")
    }
    
    // MARK: - Smart Playlist Evaluation Tests
    // Covers: Smart playlist filtering and criteria evaluation from content spec
    
    func testSmartPlaylistEvaluationWithUnplayedFilter() async {
        // Given: Smart playlist filtering for unplayed episodes
        let criteria = SmartPlaylistCriteria(
            maxEpisodes: 10,
            orderBy: .dateAdded,
            filterRules: [.isPlayed(false)]
        )
        let smartPlaylist = SmartPlaylist(name: "Unplayed", criteria: criteria)
        
        // When: Evaluating smart playlist
        let evaluatedEpisodes = await playlistEngine.evaluateSmartPlaylist(
            smartPlaylist,
            episodes: sampleEpisodes,
            downloadStatuses: downloadStatuses
        )
        
        // Then: Should only include unplayed episodes
        XCTAssertEqual(evaluatedEpisodes.count, 2) // ep1 and ep2 are unplayed
        XCTAssertTrue(evaluatedEpisodes.allSatisfy { !$0.isPlayed })
    }
    
    func testSmartPlaylistEvaluationWithDownloadedFilter() async {
        // Given: Smart playlist filtering for downloaded episodes
        let criteria = SmartPlaylistCriteria(
            maxEpisodes: 10,
            orderBy: .dateAdded,
            filterRules: [.isDownloaded]
        )
        let smartPlaylist = SmartPlaylist(name: "Downloaded", criteria: criteria)
        
        // When: Evaluating smart playlist
        let evaluatedEpisodes = await playlistEngine.evaluateSmartPlaylist(
            smartPlaylist,
            episodes: sampleEpisodes,
            downloadStatuses: downloadStatuses
        )
        
        // Then: Should only include downloaded episodes
        XCTAssertEqual(evaluatedEpisodes.count, 2) // ep1 and ep3 are downloaded
        let downloadedIds = evaluatedEpisodes.map { $0.id }
        XCTAssertTrue(downloadedIds.contains("ep1"))
        XCTAssertTrue(downloadedIds.contains("ep3"))
    }
    
    func testSmartPlaylistMaxEpisodesLimit() async {
        // Given: Smart playlist with episode limit
        let criteria = SmartPlaylistCriteria(
            maxEpisodes: 2,
            orderBy: .dateAdded,
            filterRules: []
        )
        let smartPlaylist = SmartPlaylist(name: "Limited", criteria: criteria)
        
        // When: Evaluating smart playlist
        let evaluatedEpisodes = await playlistEngine.evaluateSmartPlaylist(
            smartPlaylist,
            episodes: sampleEpisodes,
            downloadStatuses: downloadStatuses
        )
        
        // Then: Should respect episode limit
        XCTAssertEqual(evaluatedEpisodes.count, 2)
    }
    
    // MARK: - Playlist Manager Tests
    // Covers: Playlist management operations from content spec
    
    func testCreatePlaylist() async {
        // Given: New playlist data
        let playlist = Playlist(name: "New Playlist")
        
        // When: Creating playlist
        await playlistManager.createPlaylist(playlist)
        
        // Then: Playlist should be created
        let playlists = await playlistManager.playlists
        XCTAssertEqual(playlists.count, 1)
        XCTAssertEqual(playlists.first?.name, "New Playlist")
    }
    
    func testUpdatePlaylist() async {
        // Given: Existing playlist
        let playlist = Playlist(name: "Original")
        await playlistManager.createPlaylist(playlist)
        
        // When: Updating playlist
        let updatedPlaylist = playlist.withName("Updated")
        await playlistManager.updatePlaylist(updatedPlaylist)
        
        // Then: Playlist should be updated
        let found = await playlistManager.findPlaylist(id: playlist.id)
        XCTAssertEqual(found?.name, "Updated")
    }
    
    func testDeletePlaylist() async {
        // Given: Existing playlist
        let playlist = Playlist(name: "To Delete")
        await playlistManager.createPlaylist(playlist)
        
        // When: Deleting playlist
        await playlistManager.deletePlaylist(id: playlist.id)
        
        // Then: Playlist should be removed
        let playlists = await playlistManager.playlists
        XCTAssertTrue(playlists.isEmpty)
    }
    
    func testAddEpisodeToPlaylist() async {
        // Given: Existing playlist
        let playlist = Playlist(name: "Episode Test")
        await playlistManager.createPlaylist(playlist)
        
        // When: Adding episode to playlist
        await playlistManager.addEpisode(episodeId: "ep1", to: playlist.id)
        
        // Then: Episode should be added
        let updated = await playlistManager.findPlaylist(id: playlist.id)
        XCTAssertTrue(updated?.episodeIds.contains("ep1") ?? false)
    }
    
    func testRemoveEpisodeFromPlaylist() async {
        // Given: Playlist with episodes
        let playlist = Playlist(name: "Remove Test", episodeIds: ["ep1", "ep2"])
        await playlistManager.createPlaylist(playlist)
        
        // When: Removing episode from playlist
        await playlistManager.removeEpisode(episodeId: "ep1", from: playlist.id)
        
        // Then: Episode should be removed
        let updated = await playlistManager.findPlaylist(id: playlist.id)
        XCTAssertFalse(updated?.episodeIds.contains("ep1") ?? true)
        XCTAssertTrue(updated?.episodeIds.contains("ep2") ?? false)
    }
    
    // MARK: - Playlist Change Notifications Tests
    // Covers: Real-time updates and notifications from content spec
    
    #if canImport(Combine)
    func testPlaylistChangeNotifications() async throws {
        // Given: Playlist manager with observer
        var receivedNotifications: [PlaylistChangeNotification] = []
        let expectation = expectation(description: "Playlist change notification")
        expectation.expectedFulfillmentCount = 2 // Create + update operations
        
        playlistManager.playlistChanges
            .sink { notification in
                receivedNotifications.append(notification)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: Creating and updating playlist
        let playlist = Playlist(name: "Notification Test")
        await playlistManager.createPlaylist(playlist)
        await playlistManager.addEpisode(episodeId: "ep1", to: playlist.id)
        
        // Then: Should receive change notifications
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedNotifications.count, 2)
    }
    #endif
    
    // MARK: - Acceptance Criteria Tests
    // Covers: Complete user workflows from content specification
    
    func testAcceptanceCriteria_ManualPlaylistCRUD() async {
        // Given: User wants to manage playlists
        // When: Creating manual playlist, adding/removing/reordering episodes
        
        // Create playlist
        let playlist = Playlist(name: "Acceptance Test")
        await playlistManager.createPlaylist(playlist)
        let playlists1 = await playlistManager.playlists
        XCTAssertEqual(playlists1.count, 1)
        
        // Add episodes
        await playlistManager.addEpisode(episodeId: "ep1", to: playlist.id)
        await playlistManager.addEpisode(episodeId: "ep2", to: playlist.id)
        await playlistManager.addEpisode(episodeId: "ep3", to: playlist.id)
        
        var updated = await playlistManager.findPlaylist(id: playlist.id)
        XCTAssertEqual(updated?.episodeIds.count, 3)
        XCTAssertEqual(updated?.episodeIds, ["ep1", "ep2", "ep3"])
        
        // Remove episode
        await playlistManager.removeEpisode(episodeId: "ep2", from: playlist.id)
        updated = await playlistManager.findPlaylist(id: playlist.id)
        XCTAssertEqual(updated?.episodeIds, ["ep1", "ep3"])
        
        // Reorder episodes
        await playlistManager.reorderEpisodes(in: playlist.id, newOrder: ["ep3", "ep1"])
        updated = await playlistManager.findPlaylist(id: playlist.id)
        XCTAssertEqual(updated?.episodeIds, ["ep3", "ep1"])
        
        // Then: All operations should succeed
        XCTAssertNotNil(updated)
    }
    
    func testAcceptanceCriteria_SmartPlaylistUpdates() async {
        // Given: Smart playlist with criteria
        let criteria = SmartPlaylistCriteria(
            maxEpisodes: 10,
            orderBy: .dateAdded,
            filterRules: [.isPlayed(false)]
        )
        let smartPlaylist = SmartPlaylist(name: "Smart Acceptance", criteria: criteria)
        await playlistManager.createSmartPlaylist(smartPlaylist)
        
        // When: Evaluating smart playlist as episodes change
        let initialEpisodes = await playlistEngine.evaluateSmartPlaylist(
            smartPlaylist,
            episodes: sampleEpisodes,
            downloadStatuses: downloadStatuses
        )
        
        // Mark an episode as played
        var modifiedEpisodes = sampleEpisodes!
        modifiedEpisodes[0] = modifiedEpisodes[0].withPlayedStatus(true)
        
        let updatedEpisodes = await playlistEngine.evaluateSmartPlaylist(
            smartPlaylist,
            episodes: modifiedEpisodes,
            downloadStatuses: downloadStatuses
        )
        
        // Then: Smart playlist should update to reflect changes
        XCTAssertEqual(initialEpisodes.count, 2) // Originally 2 unplayed
        XCTAssertEqual(updatedEpisodes.count, 1) // Now 1 unplayed after marking one played
    }
    
    func testAcceptanceCriteria_ShuffleRespected() async {
        // Given: Playlists with different shuffle settings
        let shufflePlaylist = Playlist(
            name: "Shuffle Allowed",
            episodeIds: ["ep1", "ep2", "ep3"],
            shuffleAllowed: true
        )
        
        let noShufflePlaylist = Playlist(
            name: "No Shuffle",
            episodeIds: ["ep1", "ep2", "ep3"],
            shuffleAllowed: false
        )
        
        // When: Generating queues with shuffle requested
        let shuffledQueue = await playlistEngine.generatePlaybackQueue(
            from: shufflePlaylist,
            episodes: sampleEpisodes,
            shuffle: true
        )
        
        let orderedQueue = await playlistEngine.generatePlaybackQueue(
            from: noShufflePlaylist,
            episodes: sampleEpisodes,
            shuffle: true
        )
        
        // Then: Shuffle settings should be respected
        XCTAssertEqual(shuffledQueue.count, 3)
        XCTAssertEqual(orderedQueue.count, 3)
        
        // Ordered queue should maintain original order despite shuffle request
        XCTAssertEqual(orderedQueue[0].id, "ep1")
        XCTAssertEqual(orderedQueue[1].id, "ep2")
        XCTAssertEqual(orderedQueue[2].id, "ep3")
    }
}

// MARK: - Test-only PlaylistEngine Implementation
final class PlaylistEngine: @unchecked Sendable {
    init() {}
    
    func evaluateSmartPlaylist(
        _ smartPlaylist: SmartPlaylist,
        episodes: [Episode],
        downloadStatuses: [String: DownloadState]
    ) async -> [Episode] {
        var matchingEpisodes = episodes
        
        // Apply filtering rules from criteria
        for filterRule in smartPlaylist.criteria.filterRules {
            matchingEpisodes = matchingEpisodes.filter { episode in
                matchesFilterRule(filterRule, episode: episode, downloadStatus: downloadStatuses[episode.id])
            }
        }
        
        // Apply sorting based on orderBy
        matchingEpisodes = applySorting(matchingEpisodes, orderBy: smartPlaylist.criteria.orderBy)
        
        // Apply max episodes limit
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
        
        // Maintain playlist order if shuffle not allowed or not requested
        if !shuffle || !playlist.shuffleAllowed {
            return playlist.episodeIds.compactMap { episodeId in
                matchingEpisodes.first { $0.id == episodeId }
            }
        } else {
            return matchingEpisodes.shuffled()
        }
    }
    
    func generatePlaybackQueue(
        from smartPlaylist: SmartPlaylist,
        episodes: [Episode],
        downloadStatuses: [String: DownloadState],
        shuffle: Bool = false
    ) async -> [Episode] {
        let evaluatedEpisodes = await evaluateSmartPlaylist(
            smartPlaylist,
            episodes: episodes,
            downloadStatuses: downloadStatuses
        )
        
        if shuffle && smartPlaylist.shuffleAllowed {
            return evaluatedEpisodes.shuffled()
        } else {
            return evaluatedEpisodes
        }
    }
    
    private func applySorting(_ episodes: [Episode], orderBy: SmartPlaylistOrderBy) -> [Episode] {
        switch orderBy {
        case .dateAdded:
            return episodes.sorted { ($0.pubDate ?? Date.distantPast) > ($1.pubDate ?? Date.distantPast) }
        case .publicationDate:
            return episodes.sorted { ($0.pubDate ?? Date.distantPast) > ($1.pubDate ?? Date.distantPast) }
        case .duration:
            return episodes.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
        case .random:
            return episodes.shuffled()
        }
    }
    
    private func matchesFilterRule(_ rule: SmartPlaylistFilterRule, episode: Episode, downloadStatus: DownloadState?) -> Bool {
        switch rule {
        case .isPlayed(let isPlayed):
            if isPlayed {
                return episode.isPlayed == true
            } else {
                return episode.isPlayed == false && episode.playbackPosition <= 0
            }
        case .isDownloaded:
            return downloadStatus == .completed
        case .podcastCategory(_):
            // For testing purposes, always return true
            return true
        case .dateRange(let start, let end):
            guard let pubDate = episode.pubDate else { return false }
            return pubDate >= start && pubDate <= end
        case .durationRange(let min, let max):
            guard let duration = episode.duration else { return false }
            return duration >= min && duration <= max
        }
    }
}

// MARK: - Test-only PlaylistManager Implementation
@MainActor
final class PlaylistManager: ObservableObject {
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var smartPlaylists: [SmartPlaylist] = []
    
    #if canImport(Combine)
    let playlistChanges = PassthroughSubject<PlaylistChangeNotification, Never>()
    #endif
    
    func createPlaylist(_ playlist: Playlist) async {
        playlists.append(playlist)
        #if canImport(Combine)
        playlistChanges.send(.created(playlist))
        #endif
    }
    
    func createSmartPlaylist(_ smartPlaylist: SmartPlaylist) async {
        smartPlaylists.append(smartPlaylist)
        #if canImport(Combine)
        playlistChanges.send(.smartCreated(smartPlaylist))
        #endif
    }
    
    func updatePlaylist(_ playlist: Playlist) async {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index] = playlist
            #if canImport(Combine)
            playlistChanges.send(.updated(playlist))
            #endif
        }
    }
    
    func deletePlaylist(id: String) async {
        playlists.removeAll { $0.id == id }
        smartPlaylists.removeAll { $0.id == id }
        #if canImport(Combine)
        playlistChanges.send(.deleted(id))
        #endif
    }
    
    func findPlaylist(id: String) async -> Playlist? {
        return playlists.first { $0.id == id }
    }
    
    func addEpisode(episodeId: String, to playlistId: String) async {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            var updatedEpisodeIds = playlists[index].episodeIds
            if !updatedEpisodeIds.contains(episodeId) {
                updatedEpisodeIds.append(episodeId)
                playlists[index] = playlists[index].withEpisodes(updatedEpisodeIds)
                #if canImport(Combine)
                playlistChanges.send(.episodeAdded(playlistId, episodeId))
                #endif
            }
        }
    }
    
    func removeEpisode(episodeId: String, from playlistId: String) async {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            let updatedEpisodeIds = playlists[index].episodeIds.filter { $0 != episodeId }
            playlists[index] = playlists[index].withEpisodes(updatedEpisodeIds)
            #if canImport(Combine)
            playlistChanges.send(.episodeRemoved(playlistId, episodeId))
            #endif
        }
    }
    
    func reorderEpisodes(in playlistId: String, newOrder: [String]) async {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            playlists[index] = playlists[index].withEpisodes(newOrder)
            #if canImport(Combine)
            playlistChanges.send(.episodesReordered(playlistId, newOrder))
            #endif
        }
    }
}

// MARK: - Test Support Types
enum PlaylistChangeNotification {
    case created(Playlist)
    case smartCreated(SmartPlaylist)
    case updated(Playlist)
    case deleted(String)
    case episodeAdded(String, String)
    case episodeRemoved(String, String)
    case episodesReordered(String, [String])
}

// MARK: - Episode Extensions for Testing
extension Episode {
    func withPlayedStatus(_ isPlayed: Bool) -> Episode {
        return Episode(
            id: self.id,
            title: self.title,
            podcastID: self.podcastID,
            playbackPosition: self.playbackPosition,
            isPlayed: isPlayed,
            pubDate: self.pubDate,
            duration: self.duration,
            description: self.description,
            audioURL: self.audioURL
        )
    }
}

extension Playlist {
    func withName(_ name: String) -> Playlist {
        return Playlist(
            id: self.id,
            name: name,
            episodeIds: self.episodeIds,
            continuousPlayback: self.continuousPlayback,
            shuffleAllowed: self.shuffleAllowed,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }
}
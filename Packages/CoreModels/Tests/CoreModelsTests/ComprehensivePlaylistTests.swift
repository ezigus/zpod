import XCTest
@testable import CoreModels

/// Comprehensive unit tests for Playlist and SmartPlaylist models based on spec requirements
final class ComprehensivePlaylistTests: XCTestCase {
    
    // MARK: - Test Data
    private var samplePlaylist: Playlist!
    private var sampleSmartPlaylist: SmartPlaylist!
    private let testDate = Date(timeIntervalSince1970: 1642684800) // Fixed date for consistency
    
    override func setUp() async throws {
        try await super.setUp()
        samplePlaylist = Playlist(
            id: "test-playlist-id",
            name: "My Tech Podcast Playlist",
            episodeIds: ["ep1", "ep2", "ep3"],
            continuousPlayback: true,
            shuffleAllowed: true,
            createdAt: testDate,
            updatedAt: testDate
        )
        
        sampleSmartPlaylist = SmartPlaylist(
            id: "smart-playlist-id",
            name: "Recently Added Episodes",
            episodeIds: ["ep4", "ep5"],
            continuousPlayback: true,
            shuffleAllowed: false,
            createdAt: testDate,
            updatedAt: testDate,
            criteria: SmartPlaylistCriteria(
                maxEpisodes: 20,
                orderBy: .dateAdded,
                filterRules: [
                    .isPlayed(false),
                    .podcastCategory("Technology")
                ]
            )
        )
    }
    
    // MARK: - Manual Playlist Tests
    
    func testPlaylistInitialization_WithAllProperties() {
        // Given: All playlist properties
        // When: Creating a playlist with all properties
        // Then: All properties should be correctly set
        XCTAssertEqual(samplePlaylist.id, "test-playlist-id")
        XCTAssertEqual(samplePlaylist.name, "My Tech Podcast Playlist")
        XCTAssertEqual(samplePlaylist.episodeIds, ["ep1", "ep2", "ep3"])
        XCTAssertTrue(samplePlaylist.continuousPlayback)
        XCTAssertTrue(samplePlaylist.shuffleAllowed)
        XCTAssertEqual(samplePlaylist.createdAt, testDate)
        XCTAssertEqual(samplePlaylist.updatedAt, testDate)
    }
    
    func testPlaylistInitialization_WithDefaults() {
        // Given: Creating a playlist with default values
        // When: Using the default initializer
        let defaultPlaylist = Playlist(name: "Default Playlist")
        
        // Then: Default values should be applied correctly
        XCTAssertFalse(defaultPlaylist.id.isEmpty)
        XCTAssertEqual(defaultPlaylist.name, "Default Playlist")
        XCTAssertTrue(defaultPlaylist.episodeIds.isEmpty)
        XCTAssertTrue(defaultPlaylist.continuousPlayback) // Default should be true
        XCTAssertTrue(defaultPlaylist.shuffleAllowed) // Default should be true
        XCTAssertNotNil(defaultPlaylist.createdAt)
        XCTAssertNotNil(defaultPlaylist.updatedAt)
    }
    
    func testPlaylistInitialization_WithMinimalSettings() {
        // Given: Creating a playlist with minimal settings
        // When: Disabling features
        let minimalPlaylist = Playlist(
            name: "Minimal Playlist",
            continuousPlayback: false,
            shuffleAllowed: false
        )
        
        // Then: Settings should be applied correctly
        XCTAssertEqual(minimalPlaylist.name, "Minimal Playlist")
        XCTAssertFalse(minimalPlaylist.continuousPlayback)
        XCTAssertFalse(minimalPlaylist.shuffleAllowed)
    }
    
    // MARK: - Episode Management Tests (Based on Spec)
    
    func testWithEpisodes_AddingEpisodes() {
        // Given: An empty playlist
        let emptyPlaylist = Playlist(name: "Empty Playlist")
        
        // When: Adding episodes using withEpisodes
        let episodeIds = ["ep1", "ep2", "ep3"]
        let updatedPlaylist = emptyPlaylist.withEpisodes(episodeIds)
        
        // Then: Episodes should be added and updated timestamp should change
        XCTAssertEqual(updatedPlaylist.episodeIds, episodeIds)
        XCTAssertEqual(updatedPlaylist.episodeIds.count, 3)
        XCTAssertTrue(updatedPlaylist.updatedAt > emptyPlaylist.updatedAt)
        
        // Original playlist should remain unchanged
        XCTAssertTrue(emptyPlaylist.episodeIds.isEmpty)
    }
    
    func testWithEpisodes_ReplacingEpisodes() {
        // Given: A playlist with existing episodes
        // When: Replacing with new episodes
        let newEpisodeIds = ["new1", "new2"]
        let updatedPlaylist = samplePlaylist.withEpisodes(newEpisodeIds)
        
        // Then: Episodes should be replaced
        XCTAssertEqual(updatedPlaylist.episodeIds, newEpisodeIds)
        XCTAssertEqual(updatedPlaylist.episodeIds.count, 2)
        XCTAssertNotEqual(updatedPlaylist.episodeIds, samplePlaylist.episodeIds)
        
        // Other properties should remain the same except updatedAt
        XCTAssertEqual(updatedPlaylist.id, samplePlaylist.id)
        XCTAssertEqual(updatedPlaylist.name, samplePlaylist.name)
        XCTAssertEqual(updatedPlaylist.continuousPlayback, samplePlaylist.continuousPlayback)
        XCTAssertEqual(updatedPlaylist.shuffleAllowed, samplePlaylist.shuffleAllowed)
        XCTAssertEqual(updatedPlaylist.createdAt, samplePlaylist.createdAt)
    }
    
    func testWithEpisodes_EmptyList() {
        // Given: A playlist with episodes
        // When: Setting empty episode list
        let emptyPlaylist = samplePlaylist.withEpisodes([])
        
        // Then: Should handle empty list gracefully
        XCTAssertTrue(emptyPlaylist.episodeIds.isEmpty)
        XCTAssertEqual(emptyPlaylist.episodeIds.count, 0)
    }
    
    func testWithEpisodes_DuplicateEpisodes() {
        // Given: A playlist
        // When: Adding duplicate episode IDs
        let duplicateIds = ["ep1", "ep1", "ep2", "ep1"]
        let playlistWithDuplicates = samplePlaylist.withEpisodes(duplicateIds)
        
        // Then: Should preserve all entries (allowing duplicates for potential repeat listening)
        XCTAssertEqual(playlistWithDuplicates.episodeIds, duplicateIds)
        XCTAssertEqual(playlistWithDuplicates.episodeIds.count, 4)
    }
    
    // MARK: - Continuous Playback Tests (Based on Spec)
    
    func testContinuousPlayback_Enabled() {
        // Given: A playlist with continuous playback enabled
        // When: Checking continuous playback setting
        // Then: Should be enabled as per spec requirements
        XCTAssertTrue(samplePlaylist.continuousPlayback)
    }
    
    func testContinuousPlayback_Disabled() {
        // Given: A playlist with continuous playback disabled
        let nonContinuousPlaylist = Playlist(
            name: "Non-Continuous Playlist",
            continuousPlayback: false
        )
        
        // When: Checking continuous playback setting
        // Then: Should be disabled
        XCTAssertFalse(nonContinuousPlaylist.continuousPlayback)
    }
    
    // MARK: - Shuffle Playback Tests (Based on Spec)
    
    func testShufflePlayback_Allowed() {
        // Given: A playlist with shuffle allowed
        // When: Checking shuffle setting
        // Then: Should allow shuffle as per spec requirements
        XCTAssertTrue(samplePlaylist.shuffleAllowed)
    }
    
    func testShufflePlayback_NotAllowed() {
        // Given: A playlist with shuffle not allowed
        let noShufflePlaylist = Playlist(
            name: "No Shuffle Playlist",
            shuffleAllowed: false
        )
        
        // When: Checking shuffle setting
        // Then: Should not allow shuffle
        XCTAssertFalse(noShufflePlaylist.shuffleAllowed)
    }
    
    // MARK: - Smart Playlist Tests
    
    func testSmartPlaylistInitialization_WithAllProperties() {
        // Given: All smart playlist properties
        // When: Creating a smart playlist with all properties
        // Then: All properties should be correctly set
        XCTAssertEqual(sampleSmartPlaylist.id, "smart-playlist-id")
        XCTAssertEqual(sampleSmartPlaylist.name, "Recently Added Episodes")
        XCTAssertEqual(sampleSmartPlaylist.episodeIds, ["ep4", "ep5"])
        XCTAssertTrue(sampleSmartPlaylist.continuousPlayback)
        XCTAssertFalse(sampleSmartPlaylist.shuffleAllowed)
        XCTAssertEqual(sampleSmartPlaylist.createdAt, testDate)
        XCTAssertEqual(sampleSmartPlaylist.updatedAt, testDate)
        XCTAssertNotNil(sampleSmartPlaylist.criteria)
    }
    
    func testSmartPlaylistCriteria_MaxEpisodes() {
        // Given: A smart playlist with max episodes limit
        // When: Checking criteria
        // Then: Should respect max episodes setting
        XCTAssertEqual(sampleSmartPlaylist.criteria.maxEpisodes, 20)
    }
    
    func testSmartPlaylistCriteria_OrderBy() {
        // Given: A smart playlist with ordering criteria
        // When: Checking order setting
        // Then: Should use specified ordering
        XCTAssertEqual(sampleSmartPlaylist.criteria.orderBy, .dateAdded)
    }
    
    func testSmartPlaylistCriteria_FilterRules() {
        // Given: A smart playlist with filter rules
        // When: Checking filter rules
        // Then: Should contain expected filters
        XCTAssertEqual(sampleSmartPlaylist.criteria.filterRules.count, 2)
        
        // Check specific filter rules
        let hasUnplayedFilter = sampleSmartPlaylist.criteria.filterRules.contains { rule in
            if case .isPlayed(let played) = rule, played == false {
                return true
            }
            return false
        }
        XCTAssertTrue(hasUnplayedFilter, "Should have unplayed episodes filter")
        
        let hasCategoryFilter = sampleSmartPlaylist.criteria.filterRules.contains { rule in
            if case .podcastCategory(let category) = rule, category == "Technology" {
                return true
            }
            return false
        }
        XCTAssertTrue(hasCategoryFilter, "Should have technology category filter")
    }
    
    func testSmartPlaylistCriteria_DefaultValues() {
        // Given: Creating smart playlist criteria with defaults
        // When: Using default initializer
        let defaultCriteria = SmartPlaylistCriteria()
        
        // Then: Should have sensible defaults
        XCTAssertEqual(defaultCriteria.maxEpisodes, 50) // Reasonable default
        XCTAssertEqual(defaultCriteria.orderBy, .dateAdded)
        XCTAssertTrue(defaultCriteria.filterRules.isEmpty)
    }
    
    // MARK: - Filter Rules Tests
    
    func testFilterRules_IsPlayed() {
        // Given: Filter rules for played status
        // When: Creating played/unplayed filters
        let playedFilter = SmartPlaylistFilterRule.isPlayed(true)
        let unplayedFilter = SmartPlaylistFilterRule.isPlayed(false)
        
        // Then: Should create appropriate filters
        if case .isPlayed(let played) = playedFilter {
            XCTAssertTrue(played)
        } else {
            XCTFail("Should be played filter")
        }
        
        if case .isPlayed(let played) = unplayedFilter {
            XCTAssertFalse(played)
        } else {
            XCTFail("Should be unplayed filter")
        }
    }
    
    func testFilterRules_PodcastCategory() {
        // Given: Filter rule for podcast category
        // When: Creating category filter
        let categoryFilter = SmartPlaylistFilterRule.podcastCategory("Technology")
        
        // Then: Should create appropriate filter
        if case .podcastCategory(let category) = categoryFilter {
            XCTAssertEqual(category, "Technology")
        } else {
            XCTFail("Should be category filter")
        }
    }
    
    func testFilterRules_DateRange() {
        // Given: Filter rule for date range
        // When: Creating date range filter
        let startDate = Date(timeIntervalSince1970: 1600000000)
        let endDate = Date(timeIntervalSince1970: 1700000000)
        let dateFilter = SmartPlaylistFilterRule.dateRange(start: startDate, end: endDate)
        
        // Then: Should create appropriate filter
        if case .dateRange(let start, let end) = dateFilter {
            XCTAssertEqual(start, startDate)
            XCTAssertEqual(end, endDate)
        } else {
            XCTFail("Should be date range filter")
        }
    }
    
    func testFilterRules_DurationRange() {
        // Given: Filter rule for duration range
        // When: Creating duration filter
        let minDuration: TimeInterval = 600 // 10 minutes
        let maxDuration: TimeInterval = 3600 // 60 minutes
        let durationFilter = SmartPlaylistFilterRule.durationRange(min: minDuration, max: maxDuration)
        
        // Then: Should create appropriate filter
        if case .durationRange(let min, let max) = durationFilter {
            XCTAssertEqual(min, minDuration)
            XCTAssertEqual(max, maxDuration)
        } else {
            XCTFail("Should be duration range filter")
        }
    }
    
    // MARK: - Order By Tests
    
    func testOrderBy_DateAdded() {
        // Given: Order by date added
        // When: Checking order type
        let orderBy = SmartPlaylistOrderBy.dateAdded
        
        // Then: Should be date added ordering
        XCTAssertEqual(orderBy, .dateAdded)
    }
    
    func testOrderBy_PublicationDate() {
        // Given: Order by publication date
        // When: Checking order type
        let orderBy = SmartPlaylistOrderBy.publicationDate
        
        // Then: Should be publication date ordering
        XCTAssertEqual(orderBy, .publicationDate)
    }
    
    func testOrderBy_Duration() {
        // Given: Order by duration
        // When: Checking order type
        let orderBy = SmartPlaylistOrderBy.duration
        
        // Then: Should be duration ordering
        XCTAssertEqual(orderBy, .duration)
    }
    
    func testOrderBy_Random() {
        // Given: Order by random
        // When: Checking order type
        let orderBy = SmartPlaylistOrderBy.random
        
        // Then: Should be random ordering
        XCTAssertEqual(orderBy, .random)
    }
    
    // MARK: - Codable Tests
    
    func testPlaylistCodable_FullData() throws {
        // Given: A playlist with all properties set
        // When: Encoding and decoding the playlist
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(samplePlaylist)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decodedPlaylist = try decoder.decode(Playlist.self, from: data)
        
        // Then: All properties should be preserved
        XCTAssertEqual(samplePlaylist, decodedPlaylist)
    }
    
    func testSmartPlaylistCodable_FullData() throws {
        // Given: A smart playlist with all properties set
        // When: Encoding and decoding the smart playlist
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(sampleSmartPlaylist)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decodedSmartPlaylist = try decoder.decode(SmartPlaylist.self, from: data)
        
        // Then: All properties should be preserved
        XCTAssertEqual(sampleSmartPlaylist, decodedSmartPlaylist)
    }
    
    // MARK: - Equatable Tests
    
    func testPlaylistEquatable_SameContent() {
        // Given: Two playlists with identical content
        let playlist1 = samplePlaylist!
        let playlist2 = Playlist(
            id: samplePlaylist.id,
            name: samplePlaylist.name,
            episodeIds: samplePlaylist.episodeIds,
            continuousPlayback: samplePlaylist.continuousPlayback,
            shuffleAllowed: samplePlaylist.shuffleAllowed,
            createdAt: samplePlaylist.createdAt,
            updatedAt: samplePlaylist.updatedAt
        )
        
        // When: Comparing for equality
        // Then: Should be equal
        XCTAssertEqual(playlist1, playlist2)
    }
    
    func testPlaylistEquatable_DifferentEpisodes() {
        // Given: Two playlists with different episodes
        let playlist1 = samplePlaylist!
        let playlist2 = samplePlaylist.withEpisodes(["different1", "different2"])
        
        // When: Comparing for equality
        // Then: Should not be equal
        XCTAssertNotEqual(playlist1, playlist2)
    }
    
    func testSmartPlaylistEquatable_SameContent() {
        // Given: Two smart playlists with identical content
        let smartPlaylist1 = sampleSmartPlaylist!
        let smartPlaylist2 = SmartPlaylist(
            id: sampleSmartPlaylist.id,
            name: sampleSmartPlaylist.name,
            episodeIds: sampleSmartPlaylist.episodeIds,
            continuousPlayback: sampleSmartPlaylist.continuousPlayback,
            shuffleAllowed: sampleSmartPlaylist.shuffleAllowed,
            createdAt: sampleSmartPlaylist.createdAt,
            updatedAt: sampleSmartPlaylist.updatedAt,
            criteria: sampleSmartPlaylist.criteria
        )
        
        // When: Comparing for equality
        // Then: Should be equal
        XCTAssertEqual(smartPlaylist1, smartPlaylist2)
    }
    
    // MARK: - Immutability Tests
    
    func testImmutability_WithEpisodes() {
        // Given: An original playlist
        let originalEpisodes = samplePlaylist.episodeIds
        
        // When: Creating updated version
        let updatedPlaylist = samplePlaylist.withEpisodes(["new1", "new2"])
        
        // Then: Original should remain unchanged
        XCTAssertEqual(samplePlaylist.episodeIds, originalEpisodes)
        XCTAssertEqual(updatedPlaylist.episodeIds, ["new1", "new2"])
        XCTAssertNotEqual(samplePlaylist, updatedPlaylist)
    }
    
    // MARK: - Identifiable Protocol Tests
    
    func testPlaylistIdentifiable() {
        // Given: A playlist implementing Identifiable
        // When: Accessing id property
        // Then: Should conform to Identifiable protocol
        let playlistId: String = samplePlaylist.id
        XCTAssertFalse(playlistId.isEmpty)
        XCTAssertEqual(playlistId, samplePlaylist.id)
    }
    
    func testSmartPlaylistIdentifiable() {
        // Given: A smart playlist implementing Identifiable
        // When: Accessing id property
        // Then: Should conform to Identifiable protocol
        let smartPlaylistId: String = sampleSmartPlaylist.id
        XCTAssertFalse(smartPlaylistId.isEmpty)
        XCTAssertEqual(smartPlaylistId, sampleSmartPlaylist.id)
    }
    
    // MARK: - Sendable Compliance Tests
    
    func testPlaylistSendableCompliance() {
        // Given: Playlist model should be Sendable for Swift 6 concurrency
        // When: Checking Sendable conformance
        // Then: Should compile without concurrency warnings (compile-time check)
        let _: Sendable = samplePlaylist
        XCTAssertNotNil(samplePlaylist)
    }
    
    func testSmartPlaylistSendableCompliance() {
        // Given: SmartPlaylist model should be Sendable for Swift 6 concurrency
        // When: Checking Sendable conformance
        // Then: Should compile without concurrency warnings (compile-time check)
        let _: Sendable = sampleSmartPlaylist
        XCTAssertNotNil(sampleSmartPlaylist)
    }
    
    // MARK: - Edge Cases and Boundary Tests
    
    func testEmptyPlaylistName() {
        // Given: A playlist with empty name
        let emptyNamePlaylist = Playlist(name: "")
        
        // When: Checking name
        // Then: Should handle empty string gracefully
        XCTAssertEqual(emptyNamePlaylist.name, "")
        XCTAssertTrue(emptyNamePlaylist.name.isEmpty)
    }
    
    func testVeryLongPlaylistName() {
        // Given: A playlist with very long name
        let longName = String(repeating: "Very Long Playlist Name ", count: 100)
        let longNamePlaylist = Playlist(name: longName)
        
        // When: Checking name
        // Then: Should handle long names
        XCTAssertEqual(longNamePlaylist.name, longName)
        XCTAssertTrue(longNamePlaylist.name.count > 1000)
    }
    
    func testUnicodePlaylistName() {
        // Given: A playlist with Unicode characters in name
        let unicodeName = "🎵 Lista de Reprodução de Podcasts 🎧"
        let unicodePlaylist = Playlist(name: unicodeName)
        
        // When: Checking name
        // Then: Should handle Unicode properly
        XCTAssertEqual(unicodePlaylist.name, unicodeName)
        XCTAssertTrue(unicodePlaylist.name.contains("🎵"))
        XCTAssertTrue(unicodePlaylist.name.contains("Reprodução"))
    }
    
    func testManyEpisodes() {
        // Given: A playlist with many episodes
        let manyEpisodes = (1...1000).map { "episode\($0)" }
        let largePlaylist = Playlist(name: "Large Playlist").withEpisodes(manyEpisodes)
        
        // When: Checking episode count
        // Then: Should handle large episode lists
        XCTAssertEqual(largePlaylist.episodeIds.count, 1000)
        XCTAssertEqual(largePlaylist.episodeIds.first, "episode1")
        XCTAssertEqual(largePlaylist.episodeIds.last, "episode1000")
    }
}
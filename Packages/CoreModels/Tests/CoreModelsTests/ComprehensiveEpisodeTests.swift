import XCTest
@testable import CoreModels

/// Comprehensive unit tests for Episode model based on spec requirements
final class ComprehensiveEpisodeTests: XCTestCase {
    
    // MARK: - Test Data
    private var sampleEpisode: Episode!
    private let testDate = Date(timeIntervalSince1970: 1642684800) // Fixed date for consistency
    
    override func setUp() async throws {
        try await super.setUp()
        sampleEpisode = Episode(
            id: "test-episode-id",
            title: "Introduction to Swift 6 Concurrency",
            podcastID: "tech-podcast-id",
            playbackPosition: 0,
            isPlayed: false,
            pubDate: testDate,
            duration: 3600.0, // 1 hour
            description: "A comprehensive introduction to Swift 6 concurrency features including async/await, actors, and Sendable protocols.",
            audioURL: URL(string: "https://example.com/episode1.mp3")
        )
    }
    
    // MARK: - Basic Model Tests
    
    func testEpisodeInitialization_WithAllProperties() {
        // Given: All episode properties
        // When: Creating an episode with all properties
        // Then: All properties should be correctly set
        XCTAssertEqual(sampleEpisode.id, "test-episode-id")
        XCTAssertEqual(sampleEpisode.title, "Introduction to Swift 6 Concurrency")
        XCTAssertEqual(sampleEpisode.podcastID, "tech-podcast-id")
        XCTAssertEqual(sampleEpisode.playbackPosition, 0)
        XCTAssertFalse(sampleEpisode.isPlayed)
        XCTAssertEqual(sampleEpisode.pubDate, testDate)
        XCTAssertEqual(sampleEpisode.duration, 3600.0)
        XCTAssertEqual(sampleEpisode.description, "A comprehensive introduction to Swift 6 concurrency features including async/await, actors, and Sendable protocols.")
        XCTAssertEqual(sampleEpisode.audioURL, URL(string: "https://example.com/episode1.mp3"))
    }
    
    func testEpisodeInitialization_WithMinimalProperties() {
        // Given: Minimal required properties for an episode
        // When: Creating an episode with only required properties
        let minimalEpisode = Episode(
            id: "minimal-episode",
            title: "Minimal Episode"
        )
        
        // Then: Properties should be correctly set with defaults/nil values
        XCTAssertEqual(minimalEpisode.id, "minimal-episode")
        XCTAssertEqual(minimalEpisode.title, "Minimal Episode")
        XCTAssertNil(minimalEpisode.podcastID)
        XCTAssertEqual(minimalEpisode.playbackPosition, 0)
        XCTAssertFalse(minimalEpisode.isPlayed)
        XCTAssertNil(minimalEpisode.pubDate)
        XCTAssertNil(minimalEpisode.duration)
        XCTAssertNil(minimalEpisode.description)
        XCTAssertNil(minimalEpisode.audioURL)
    }
    
    // MARK: - Playback State Management Tests (Based on Spec)
    
    func testPlaybackPosition_InitialState() {
        // Given: A new episode
        // When: Checking initial playback position
        // Then: Should start at position 0
        let newEpisode = Episode(id: "new", title: "New Episode")
        XCTAssertEqual(newEpisode.playbackPosition, 0)
        XCTAssertFalse(newEpisode.isPlayed)
    }
    
    func testWithPlaybackPosition_UpdatesPosition() {
        // Given: An episode with initial position 0
        // When: Updating playback position to 1800 seconds (30 minutes)
        let updatedEpisode = sampleEpisode.withPlaybackPosition(1800)
        
        // Then: Position should be updated while preserving other properties
        XCTAssertEqual(updatedEpisode.playbackPosition, 1800)
        XCTAssertEqual(updatedEpisode.id, sampleEpisode.id)
        XCTAssertEqual(updatedEpisode.title, sampleEpisode.title)
        XCTAssertEqual(updatedEpisode.isPlayed, sampleEpisode.isPlayed)
        
        // Original episode should remain unchanged
        XCTAssertEqual(sampleEpisode.playbackPosition, 0)
    }
    
    func testWithPlaybackPosition_EdgeCases() {
        // Given: An episode
        // When: Setting various edge case positions
        let negativePosition = sampleEpisode.withPlaybackPosition(-10)
        let zeroPosition = sampleEpisode.withPlaybackPosition(0)
        let largePosition = sampleEpisode.withPlaybackPosition(999999)
        
        // Then: Should handle edge cases appropriately
        XCTAssertEqual(negativePosition.playbackPosition, -10) // Allows negative for rewind scenarios
        XCTAssertEqual(zeroPosition.playbackPosition, 0)
        XCTAssertEqual(largePosition.playbackPosition, 999999)
    }
    
    func testWithPlayedStatus_MarksAsPlayed() {
        // Given: An unplayed episode
        // When: Marking as played
        let playedEpisode = sampleEpisode.withPlayedStatus(true)
        
        // Then: Should be marked as played while preserving other properties
        XCTAssertTrue(playedEpisode.isPlayed)
        XCTAssertEqual(playedEpisode.id, sampleEpisode.id)
        XCTAssertEqual(playedEpisode.title, sampleEpisode.title)
        XCTAssertEqual(playedEpisode.playbackPosition, sampleEpisode.playbackPosition)
        
        // Original episode should remain unchanged
        XCTAssertFalse(sampleEpisode.isPlayed)
    }
    
    func testWithPlayedStatus_MarksAsUnplayed() {
        // Given: A played episode
        let playedEpisode = sampleEpisode.withPlayedStatus(true)
        
        // When: Marking as unplayed
        let unplayedEpisode = playedEpisode.withPlayedStatus(false)
        
        // Then: Should be marked as unplayed
        XCTAssertFalse(unplayedEpisode.isPlayed)
        XCTAssertEqual(unplayedEpisode.id, sampleEpisode.id)
        XCTAssertEqual(unplayedEpisode.title, sampleEpisode.title)
    }
    
    // MARK: - Episode Duration and Progress Tests
    
    func testDurationHandling_ValidDuration() {
        // Given: An episode with 1-hour duration
        // When: Checking duration properties
        // Then: Should correctly handle duration in seconds
        XCTAssertEqual(sampleEpisode.duration, 3600.0)
        
        // Test progress calculation scenarios
        let halfwayEpisode = sampleEpisode.withPlaybackPosition(1800) // 30 minutes
        XCTAssertEqual(halfwayEpisode.playbackPosition, 1800)
        
        // Progress would be 1800/3600 = 0.5 (50%)
        if let duration = halfwayEpisode.duration {
            let progress = Double(halfwayEpisode.playbackPosition) / duration
            XCTAssertEqual(progress, 0.5, accuracy: 0.001)
        } else {
            XCTFail("Duration should not be nil")
        }
    }
    
    func testDurationHandling_NilDuration() {
        // Given: An episode without duration information
        let noDurationEpisode = Episode(
            id: "no-duration",
            title: "Episode Without Duration",
            duration: nil
        )
        
        // When: Checking duration
        // Then: Should handle nil duration gracefully
        XCTAssertNil(noDurationEpisode.duration)
    }
    
    func testDurationHandling_ZeroDuration() {
        // Given: An episode with zero duration
        let zeroDurationEpisode = Episode(
            id: "zero-duration",
            title: "Zero Duration Episode",
            duration: 0.0
        )
        
        // When: Checking duration
        // Then: Should handle zero duration
        XCTAssertEqual(zeroDurationEpisode.duration, 0.0)
    }
    
    // MARK: - Episode Publication Date Tests
    
    func testPubDate_WithValidDate() {
        // Given: An episode with publication date
        // When: Checking publication date
        // Then: Should correctly store and retrieve the date
        XCTAssertEqual(sampleEpisode.pubDate, testDate)
    }
    
    func testPubDate_WithNilDate() {
        // Given: An episode without publication date
        let noDateEpisode = Episode(
            id: "no-date",
            title: "Episode Without Date",
            pubDate: nil
        )
        
        // When: Checking publication date
        // Then: Should handle nil date gracefully
        XCTAssertNil(noDateEpisode.pubDate)
    }
    
    // MARK: - Episode Content Tests
    
    func testDescription_WithContent() {
        // Given: An episode with description
        // When: Checking description content
        // Then: Should preserve full description
        XCTAssertEqual(sampleEpisode.description, "A comprehensive introduction to Swift 6 concurrency features including async/await, actors, and Sendable protocols.")
        XCTAssertTrue(sampleEpisode.description!.contains("Swift 6"))
        XCTAssertTrue(sampleEpisode.description!.contains("concurrency"))
    }
    
    func testDescription_WithNilContent() {
        // Given: An episode without description
        let noDescriptionEpisode = Episode(
            id: "no-desc",
            title: "Episode Without Description",
            description: nil
        )
        
        // When: Checking description
        // Then: Should handle nil description gracefully
        XCTAssertNil(noDescriptionEpisode.description)
    }
    
    func testAudioURL_WithValidURL() {
        // Given: An episode with audio URL
        // When: Checking audio URL
        // Then: Should correctly store and retrieve the URL
        XCTAssertEqual(sampleEpisode.audioURL, URL(string: "https://example.com/episode1.mp3"))
        XCTAssertNotNil(sampleEpisode.audioURL)
    }
    
    func testAudioURL_WithNilURL() {
        // Given: An episode without audio URL
        let noURLEpisode = Episode(
            id: "no-url",
            title: "Episode Without URL",
            audioURL: nil
        )
        
        // When: Checking audio URL
        // Then: Should handle nil URL gracefully
        XCTAssertNil(noURLEpisode.audioURL)
    }
    
    // MARK: - Podcast Relationship Tests
    
    func testPodcastID_WithValidID() {
        // Given: An episode associated with a podcast
        // When: Checking podcast relationship
        // Then: Should correctly maintain podcast association
        XCTAssertEqual(sampleEpisode.podcastID, "tech-podcast-id")
        XCTAssertNotNil(sampleEpisode.podcastID)
    }
    
    func testPodcastID_WithNilID() {
        // Given: An episode not associated with a podcast
        let orphanEpisode = Episode(
            id: "orphan",
            title: "Orphan Episode",
            podcastID: nil
        )
        
        // When: Checking podcast relationship
        // Then: Should handle nil podcast ID gracefully
        XCTAssertNil(orphanEpisode.podcastID)
    }
    
    // MARK: - Codable Tests
    
    func testEpisodeCodable_FullData() throws {
        // Given: An episode with all properties set
        // When: Encoding and decoding the episode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(sampleEpisode)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decodedEpisode = try decoder.decode(Episode.self, from: data)
        
        // Then: All properties should be preserved
        XCTAssertEqual(sampleEpisode, decodedEpisode)
    }
    
    func testEpisodeCodable_WithNilValues() throws {
        // Given: An episode with nil values
        let episodeWithNils = Episode(
            id: "nil-test",
            title: "Nil Test Episode",
            podcastID: nil,
            playbackPosition: 0,
            isPlayed: false,
            pubDate: nil,
            duration: nil,
            description: nil,
            audioURL: nil
        )
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(episodeWithNils)
        
        let decoder = JSONDecoder()
        let decodedEpisode = try decoder.decode(Episode.self, from: data)
        
        // Then: Nil values should be preserved
        XCTAssertEqual(episodeWithNils, decodedEpisode)
        XCTAssertNil(decodedEpisode.podcastID)
        XCTAssertNil(decodedEpisode.pubDate)
        XCTAssertNil(decodedEpisode.duration)
        XCTAssertNil(decodedEpisode.description)
        XCTAssertNil(decodedEpisode.audioURL)
    }
    
    // MARK: - Equatable Tests
    
    func testEpisodeEquatable_SameContent() {
        // Given: Two episodes with identical content
        let episode1 = sampleEpisode!
        let episode2 = Episode(
            id: sampleEpisode.id,
            title: sampleEpisode.title,
            podcastID: sampleEpisode.podcastID,
            playbackPosition: sampleEpisode.playbackPosition,
            isPlayed: sampleEpisode.isPlayed,
            pubDate: sampleEpisode.pubDate,
            duration: sampleEpisode.duration,
            description: sampleEpisode.description,
            audioURL: sampleEpisode.audioURL
        )
        
        // When: Comparing for equality
        // Then: Should be equal
        XCTAssertEqual(episode1, episode2)
    }
    
    func testEpisodeEquatable_DifferentPlaybackPosition() {
        // Given: Two episodes with different playback positions
        let episode1 = sampleEpisode!
        let episode2 = sampleEpisode.withPlaybackPosition(1800)
        
        // When: Comparing for equality
        // Then: Should not be equal
        XCTAssertNotEqual(episode1, episode2)
    }
    
    func testEpisodeEquatable_DifferentPlayedStatus() {
        // Given: Two episodes with different played status
        let episode1 = sampleEpisode!
        let episode2 = sampleEpisode.withPlayedStatus(true)
        
        // When: Comparing for equality
        // Then: Should not be equal
        XCTAssertNotEqual(episode1, episode2)
    }
    
    // MARK: - Immutability and Functional Updates Tests
    
    func testImmutability_WithPlaybackPosition() {
        // Given: An original episode
        let originalPosition = sampleEpisode.playbackPosition
        
        // When: Creating updated version
        let updatedEpisode = sampleEpisode.withPlaybackPosition(2400)
        
        // Then: Original should remain unchanged
        XCTAssertEqual(sampleEpisode.playbackPosition, originalPosition)
        XCTAssertEqual(updatedEpisode.playbackPosition, 2400)
        XCTAssertNotEqual(sampleEpisode, updatedEpisode)
    }
    
    func testImmutability_WithPlayedStatus() {
        // Given: An original episode
        let originalStatus = sampleEpisode.isPlayed
        
        // When: Creating updated version
        let updatedEpisode = sampleEpisode.withPlayedStatus(true)
        
        // Then: Original should remain unchanged
        XCTAssertEqual(sampleEpisode.isPlayed, originalStatus)
        XCTAssertTrue(updatedEpisode.isPlayed)
        XCTAssertNotEqual(sampleEpisode, updatedEpisode)
    }
    
    func testChainedUpdates() {
        // Given: An original episode
        // When: Chaining multiple updates
        let updatedEpisode = sampleEpisode
            .withPlaybackPosition(1200)
            .withPlayedStatus(true)
        
        // Then: All updates should be applied correctly
        XCTAssertEqual(updatedEpisode.playbackPosition, 1200)
        XCTAssertTrue(updatedEpisode.isPlayed)
        
        // Original should remain unchanged
        XCTAssertEqual(sampleEpisode.playbackPosition, 0)
        XCTAssertFalse(sampleEpisode.isPlayed)
    }
    
    // MARK: - Sendable Compliance Tests
    
    func testEpisodeSendableCompliance() {
        // Given: Episode model should be Sendable for Swift 6 concurrency
        // When: Checking Sendable conformance
        // Then: Should compile without concurrency warnings (compile-time check)
        let _: Sendable = sampleEpisode
        XCTAssertNotNil(sampleEpisode)
    }
    
    // MARK: - Edge Cases and Boundary Tests
    
    func testEmptyTitle() {
        // Given: An episode with empty title
        let emptyTitleEpisode = Episode(id: "empty", title: "")
        
        // When: Checking title
        // Then: Should handle empty string gracefully
        XCTAssertEqual(emptyTitleEpisode.title, "")
        XCTAssertTrue(emptyTitleEpisode.title.isEmpty)
    }
    
    func testVeryLongTitle() {
        // Given: An episode with very long title
        let longTitle = String(repeating: "Very Long Episode Title ", count: 100)
        let longTitleEpisode = Episode(id: "long", title: longTitle)
        
        // When: Checking title
        // Then: Should handle long titles
        XCTAssertEqual(longTitleEpisode.title, longTitle)
        XCTAssertTrue(longTitleEpisode.title.count > 1000)
    }
    
    func testUnicodeTitle() {
        // Given: An episode with Unicode characters in title
        let unicodeTitle = "🎧 Episódio sobre Programação em Swift 📱"
        let unicodeEpisode = Episode(id: "unicode", title: unicodeTitle)
        
        // When: Checking title
        // Then: Should handle Unicode properly
        XCTAssertEqual(unicodeEpisode.title, unicodeTitle)
        XCTAssertTrue(unicodeEpisode.title.contains("🎧"))
        XCTAssertTrue(unicodeEpisode.title.contains("Programação"))
    }
}
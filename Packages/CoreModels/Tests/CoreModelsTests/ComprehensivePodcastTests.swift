import XCTest
@testable import CoreModels

/// Comprehensive unit tests for Podcast model based on spec requirements
final class ComprehensivePodcastTests: XCTestCase {
    
    // MARK: - Test Data
    private var samplePodcast: Podcast!
    private let testDate = Date(timeIntervalSince1970: 1642684800) // Fixed date for consistency
    
    override func setUp() async throws {
        try await super.setUp()
        samplePodcast = Podcast(
            id: "test-podcast-id",
            title: "Test Technology Podcast",
            author: "Tech Expert",
            description: "A comprehensive technology podcast covering software development and engineering.",
            artworkURL: URL(string: "https://example.com/artwork.jpg"),
            feedURL: URL(string: "https://example.com/feed.xml")!,
            categories: ["Technology", "Education", "Software Development"],
            episodes: [],
            isSubscribed: true,
            dateAdded: testDate,
            folderId: "tech-folder",
            tagIds: ["programming", "swift"]
        )
    }
    
    // MARK: - Basic Model Tests
    
    func testPodcastInitialization_WithAllProperties() {
        // Given: All podcast properties
        // When: Creating a podcast with all properties
        // Then: All properties should be correctly set
        XCTAssertEqual(samplePodcast.id, "test-podcast-id")
        XCTAssertEqual(samplePodcast.title, "Test Technology Podcast")
        XCTAssertEqual(samplePodcast.author, "Tech Expert")
        XCTAssertEqual(samplePodcast.description, "A comprehensive technology podcast covering software development and engineering.")
        XCTAssertEqual(samplePodcast.artworkURL, URL(string: "https://example.com/artwork.jpg"))
        XCTAssertEqual(samplePodcast.feedURL, URL(string: "https://example.com/feed.xml"))
        XCTAssertEqual(samplePodcast.categories, ["Technology", "Education", "Software Development"])
        XCTAssertTrue(samplePodcast.episodes.isEmpty)
        XCTAssertTrue(samplePodcast.isSubscribed)
        XCTAssertEqual(samplePodcast.dateAdded, testDate)
        XCTAssertEqual(samplePodcast.folderId, "tech-folder")
        XCTAssertEqual(samplePodcast.tagIds, ["programming", "swift"])
    }
    
    func testPodcastInitialization_WithMinimalProperties() {
        // Given: Minimal required properties for a podcast
        // When: Creating a podcast with only required properties
        let minimalPodcast = Podcast(
            id: "minimal-id",
            title: "Minimal Podcast",
            author: nil,
            description: nil,
            artworkURL: nil,
            feedURL: URL(string: "https://example.com/minimal.xml")!,
            categories: [],
            episodes: [],
            isSubscribed: false,
            dateAdded: testDate,
            folderId: nil,
            tagIds: []
        )
        
        // Then: Properties should be correctly set with defaults/nil values
        XCTAssertEqual(minimalPodcast.id, "minimal-id")
        XCTAssertEqual(minimalPodcast.title, "Minimal Podcast")
        XCTAssertNil(minimalPodcast.author)
        XCTAssertNil(minimalPodcast.description)
        XCTAssertNil(minimalPodcast.artworkURL)
        XCTAssertEqual(minimalPodcast.feedURL, URL(string: "https://example.com/minimal.xml"))
        XCTAssertTrue(minimalPodcast.categories.isEmpty)
        XCTAssertTrue(minimalPodcast.episodes.isEmpty)
        XCTAssertFalse(minimalPodcast.isSubscribed)
        XCTAssertEqual(minimalPodcast.dateAdded, testDate)
        XCTAssertNil(minimalPodcast.folderId)
        XCTAssertTrue(minimalPodcast.tagIds.isEmpty)
    }
    
    // MARK: - Subscription Management Tests (Based on Spec)
    
    func testSubscriptionStatus_NewPodcast() {
        // Given: A newly created podcast
        // When: Checking subscription status
        // Then: Should accurately reflect subscription state
        let newPodcast = Podcast(
            id: "new-id",
            title: "New Podcast",
            author: "New Author",
            description: "New Description",
            artworkURL: nil,
            feedURL: URL(string: "https://example.com/new.xml")!,
            categories: ["News"],
            episodes: [],
            isSubscribed: true,
            dateAdded: Date(),
            folderId: nil,
            tagIds: []
        )
        
        XCTAssertTrue(newPodcast.isSubscribed, "Newly subscribed podcast should have isSubscribed = true")
    }
    
    func testPodcastCategories_MultipleCategories() {
        // Given: A podcast with multiple categories (as per spec browsing features)
        // When: Accessing categories
        // Then: Should support multiple category classification
        XCTAssertEqual(samplePodcast.categories.count, 3)
        XCTAssertTrue(samplePodcast.categories.contains("Technology"))
        XCTAssertTrue(samplePodcast.categories.contains("Education"))
        XCTAssertTrue(samplePodcast.categories.contains("Software Development"))
    }
    
    // MARK: - Organization and Tagging Tests (Based on Spec)
    
    func testFolderOrganization() {
        // Given: A podcast in a folder (as per spec hierarchical organization)
        // When: Checking folder assignment
        // Then: Should support folder-based organization
        XCTAssertEqual(samplePodcast.folderId, "tech-folder")
        XCTAssertNotNil(samplePodcast.folderId, "Podcast should support folder organization")
    }
    
    func testTagOrganization_MultipleTags() {
        // Given: A podcast with multiple tags (as per spec flat organization)
        // When: Checking tag assignments
        // Then: Should support multiple tag classification
        XCTAssertEqual(samplePodcast.tagIds.count, 2)
        XCTAssertTrue(samplePodcast.tagIds.contains("programming"))
        XCTAssertTrue(samplePodcast.tagIds.contains("swift"))
    }
    
    func testTagOrganization_NoTags() {
        // Given: A podcast without tags
        // When: Creating podcast with empty tag list
        let untaggedPodcast = Podcast(
            id: "untagged",
            title: "Untagged Podcast",
            author: nil,
            description: nil,
            artworkURL: nil,
            feedURL: URL(string: "https://example.com/untagged.xml")!,
            categories: [],
            episodes: [],
            isSubscribed: false,
            dateAdded: Date(),
            folderId: nil,
            tagIds: []
        )
        
        // Then: Should handle empty tag list gracefully
        XCTAssertTrue(untaggedPodcast.tagIds.isEmpty)
    }
    
    // MARK: - Codable Tests
    
    func testPodcastCodable_FullData() throws {
        // Given: A podcast with all properties set
        // When: Encoding and decoding the podcast
        let encoder = JSONEncoder()
        let data = try encoder.encode(samplePodcast)
        
        let decoder = JSONDecoder()
        let decodedPodcast = try decoder.decode(Podcast.self, from: data)
        
        // Then: All properties should be preserved
        XCTAssertEqual(samplePodcast, decodedPodcast)
    }
    
    func testPodcastCodable_WithNilValues() throws {
        // Given: A podcast with nil values
        let podcastWithNils = Podcast(
            id: "nil-test",
            title: "Nil Test Podcast",
            author: nil,
            description: nil,
            artworkURL: nil,
            feedURL: URL(string: "https://example.com/nil.xml")!,
            categories: [],
            episodes: [],
            isSubscribed: false,
            dateAdded: testDate,
            folderId: nil,
            tagIds: []
        )
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(podcastWithNils)
        
        let decoder = JSONDecoder()
        let decodedPodcast = try decoder.decode(Podcast.self, from: data)
        
        // Then: Nil values should be preserved
        XCTAssertEqual(podcastWithNils, decodedPodcast)
        XCTAssertNil(decodedPodcast.author)
        XCTAssertNil(decodedPodcast.description)
        XCTAssertNil(decodedPodcast.artworkURL)
        XCTAssertNil(decodedPodcast.folderId)
    }
    
    // MARK: - Equatable Tests
    
    func testPodcastEquatable_SameContent() {
        // Given: Two podcasts with identical content
        let podcast1 = samplePodcast!
        let podcast2 = Podcast(
            id: samplePodcast.id,
            title: samplePodcast.title,
            author: samplePodcast.author,
            description: samplePodcast.description,
            artworkURL: samplePodcast.artworkURL,
            feedURL: samplePodcast.feedURL,
            categories: samplePodcast.categories,
            episodes: samplePodcast.episodes,
            isSubscribed: samplePodcast.isSubscribed,
            dateAdded: samplePodcast.dateAdded,
            folderId: samplePodcast.folderId,
            tagIds: samplePodcast.tagIds
        )
        
        // When: Comparing for equality
        // Then: Should be equal
        XCTAssertEqual(podcast1, podcast2)
    }
    
    func testPodcastEquatable_DifferentId() {
        // Given: Two podcasts with different IDs
        let podcast1 = samplePodcast!
        let podcast2 = Podcast(
            id: "different-id",
            title: samplePodcast.title,
            author: samplePodcast.author,
            description: samplePodcast.description,
            artworkURL: samplePodcast.artworkURL,
            feedURL: samplePodcast.feedURL,
            categories: samplePodcast.categories,
            episodes: samplePodcast.episodes,
            isSubscribed: samplePodcast.isSubscribed,
            dateAdded: samplePodcast.dateAdded,
            folderId: samplePodcast.folderId,
            tagIds: samplePodcast.tagIds
        )
        
        // When: Comparing for equality
        // Then: Should not be equal
        XCTAssertNotEqual(podcast1, podcast2)
    }
    
    // MARK: - Edge Cases and Validation
    
    func testPodcastWithEpisodes() {
        // Given: A podcast with episodes
        let episode1 = Episode(id: "ep1", title: "Episode 1", podcastID: samplePodcast.id)
        let episode2 = Episode(id: "ep2", title: "Episode 2", podcastID: samplePodcast.id)
        
        let podcastWithEpisodes = Podcast(
            id: samplePodcast.id,
            title: samplePodcast.title,
            author: samplePodcast.author,
            description: samplePodcast.description,
            artworkURL: samplePodcast.artworkURL,
            feedURL: samplePodcast.feedURL,
            categories: samplePodcast.categories,
            episodes: [episode1, episode2],
            isSubscribed: samplePodcast.isSubscribed,
            dateAdded: samplePodcast.dateAdded,
            folderId: samplePodcast.folderId,
            tagIds: samplePodcast.tagIds
        )
        
        // When: Checking episode count
        // Then: Should properly manage episode relationships
        XCTAssertEqual(podcastWithEpisodes.episodes.count, 2)
        XCTAssertEqual(podcastWithEpisodes.episodes[0].title, "Episode 1")
        XCTAssertEqual(podcastWithEpisodes.episodes[1].title, "Episode 2")
    }
    
    func testPodcastSendableCompliance() {
        // Given: Podcast model should be Sendable for Swift 6 concurrency
        // When: Checking Sendable conformance
        // Then: Should compile without concurrency warnings (compile-time check)
        let _: Sendable = samplePodcast
        XCTAssertNotNil(samplePodcast)
    }
}
import XCTest
@testable import zpod

/// Unit tests for the Podcast model, based on spec/discovery.md and spec/content.md
class PodcastTests: XCTestCase {
    func testPodcastInitialization() {
        let podcast = Podcast(
            id: "test-id",
            title: "Test Podcast",
            author: "Test Author",
            description: "A test podcast description.",
            artworkURL: URL(string: "https://example.com/artwork.png"),
            feedURL: URL(string: "https://example.com/feed.xml")!,
            categories: ["Technology", "Education"],
            episodes: [],
            isSubscribed: true,
            dateAdded: Date()
        )
        XCTAssertEqual(podcast.id, "test-id")
        XCTAssertEqual(podcast.title, "Test Podcast")
        XCTAssertEqual(podcast.author, "Test Author")
        XCTAssertEqual(podcast.description, "A test podcast description.")
        XCTAssertEqual(podcast.artworkURL, URL(string: "https://example.com/artwork.png"))
        XCTAssertEqual(podcast.feedURL, URL(string: "https://example.com/feed.xml"))
        XCTAssertEqual(podcast.categories, ["Technology", "Education"])
        XCTAssertTrue(podcast.episodes.isEmpty)
        XCTAssertTrue(podcast.isSubscribed)
    }

    func testPodcastCodable() throws {
        // Use a fixed date to avoid floating-point precision issues in encode/decode
        let fixedDate = Date(timeIntervalSince1970: 1642684800) // 2022-01-20 12:00:00 UTC
        let podcast = Podcast(
            id: "test-id",
            title: "Test Podcast",
            author: "Test Author",
            description: "A test podcast description.",
            artworkURL: URL(string: "https://example.com/artwork.png"),
            feedURL: URL(string: "https://example.com/feed.xml")!,
            categories: ["Technology", "Education"],
            episodes: [],
            isSubscribed: false,
            dateAdded: fixedDate
        )
        // Use default JSON encoder/decoder since Podcast implements custom Codable
        let encoder = JSONEncoder()
        let data = try encoder.encode(podcast)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Podcast.self, from: data)
        XCTAssertEqual(podcast, decoded)
    }

    func testPodcastEquatable() {
        let date = Date()
        let podcast1 = Podcast(
            id: "id1",
            title: "Podcast 1",
            author: nil,
            description: nil,
            artworkURL: nil,
            feedURL: URL(string: "https://example.com/feed1.xml")!,
            categories: [],
            episodes: [],
            isSubscribed: false,
            dateAdded: date
        )
        let podcast2 = Podcast(
            id: "id1",
            title: "Podcast 1",
            author: nil,
            description: nil,
            artworkURL: nil,
            feedURL: URL(string: "https://example.com/feed1.xml")!,
            categories: [],
            episodes: [],
            isSubscribed: false,
            dateAdded: date
        )
        XCTAssertEqual(podcast1, podcast2)
    }
}

import Foundation
import XCTest
@testable import FeedParsing
import CoreModels

/// Podcast-level metadata, fixtures, and full-feed integration coverage.
final class RSSFeedParserPodcastTests: XCTestCase {

    // MARK: - Podcast-Level Data

    func testParsesPodcastTitle() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>My Awesome Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.title, "My Awesome Podcast")
    }

    func testParsesPodcastMetadata() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Tech Talks</title>
            <description>A show about technology</description>
            <itunes:author>John Doe</itunes:author>
            <itunes:image href="https://example.com/artwork.jpg"/>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.title, "Tech Talks")
        XCTAssertEqual(podcast.description, "A show about technology")
        XCTAssertEqual(podcast.author, "John Doe")
        XCTAssertEqual(podcast.artworkURL?.absoluteString, "https://example.com/artwork.jpg")
    }

    // MARK: - Comprehensive Integration

    func testParsesCompleteFeedWithAllFeatures() throws {
        // This test uses inline XML that matches the sample-feed.xml fixture
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Tech Podcast</title>
            <description>A podcast about technology</description>
            <itunes:author>Test Author</itunes:author>
            <itunes:image href="https://example.com/artwork.jpg"/>
            <itunes:category text="Technology"/>

            <item>
              <title>Episode 1: Introduction</title>
              <guid isPermaLink="false">ep-001</guid>
              <pubDate>Wed, 15 Jan 2025 10:00:00 GMT</pubDate>
              <enclosure url="https://example.com/episodes/001.mp3" type="audio/mpeg" length="45000000"/>
              <description>Welcome to the show!</description>
              <itunes:summary>A brief introduction to our podcast.</itunes:summary>
              <itunes:duration>01:15:30</itunes:duration>
              <itunes:image href="https://example.com/ep001-art.jpg"/>
            </item>

            <item>
              <title>Episode 2: Deep Dive</title>
              <guid isPermaLink="false">ep-002</guid>
              <pubDate>Wed, 22 Jan 2025 10:00:00 GMT</pubDate>
              <enclosure url="https://example.com/episodes/002.mp3" type="audio/mpeg" length="60000000"/>
              <description>We go deep on the topic.</description>
              <itunes:duration>5400</itunes:duration>
            </item>

            <!-- Episode with no enclosure - should be skipped -->
            <item>
              <title>Bonus: Text-only post</title>
              <guid>bonus-001</guid>
              <description>This is just a blog post, no audio.</description>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.title, "Tech Podcast")
        XCTAssertEqual(podcast.description, "A podcast about technology")
        XCTAssertEqual(podcast.author, "Test Author")
        XCTAssertEqual(podcast.artworkURL?.absoluteString, "https://example.com/artwork.jpg")
        XCTAssertTrue(podcast.categories.contains("Technology"))

        // Should have 3 episodes; the third has no enclosure and should be kept with nil audioURL
        XCTAssertEqual(podcast.episodes.count, 3)

        // Episode 1 verification
        let ep1 = podcast.episodes[0]
        XCTAssertEqual(ep1.id, "ep-001")
        XCTAssertEqual(ep1.title, "Episode 1: Introduction")
        XCTAssertEqual(ep1.audioURL?.absoluteString, "https://example.com/episodes/001.mp3")
        XCTAssertEqual(ep1.duration, 4530) // 01:15:30 = 75*60 + 30
        XCTAssertEqual(ep1.description, "A brief introduction to our podcast.")
        XCTAssertEqual(ep1.artworkURL?.absoluteString, "https://example.com/ep001-art.jpg")
        XCTAssertNotNil(ep1.pubDate)

        // Episode 2 verification
        let ep2 = podcast.episodes[1]
        XCTAssertEqual(ep2.id, "ep-002")
        XCTAssertEqual(ep2.title, "Episode 2: Deep Dive")
        XCTAssertEqual(ep2.audioURL?.absoluteString, "https://example.com/episodes/002.mp3")
        XCTAssertEqual(ep2.duration, 5400)
        XCTAssertEqual(ep2.description, "We go deep on the topic.")
        XCTAssertNil(ep2.artworkURL) // No episode-specific artwork

        // Episode 3 (no enclosure) verification
        let ep3 = podcast.episodes[2]
        XCTAssertEqual(ep3.id, "bonus-001")
        XCTAssertEqual(ep3.title, "Bonus: Text-only post")
        XCTAssertNil(ep3.audioURL)
        XCTAssertEqual(ep3.description, "This is just a blog post, no audio.")
    }

    // MARK: - Real Feed Fixtures

    func testParsesRealATPSampleFeed() throws {
        guard let fixtureURL = Bundle.module.url(
            forResource: "atp-feed-sample",
            withExtension: "xml",
            subdirectory: "Fixtures"
        ) else {
            return XCTFail("Missing fixture: atp-feed-sample.xml")
        }
        let data = try Data(contentsOf: fixtureURL)
        let feedURL = URL(string: "https://atp.fm/episodes?format=rss")!

        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.title, "Accidental Tech Podcast")
        XCTAssertEqual(podcast.author, "Marco Arment, Casey Liss, John Siracusa")
        XCTAssertEqual(podcast.episodes.count, 2)

        let first = podcast.episodes[0]
        XCTAssertEqual(first.id, "c1hrwkrnejz3b1do")
        XCTAssertEqual(first.audioURL?.absoluteString, "https://atp.fm/audio/c1hrwkrnejz3b1do/atp675.mp3")
        XCTAssertEqual(first.duration, 7563)

        let second = podcast.episodes[1]
        XCTAssertEqual(second.id, "mmlultngwkhmalls")
        XCTAssertEqual(second.audioURL?.absoluteString, "https://atp.fm/audio/mmlultngwkhmalls/atp674.mp3")
        XCTAssertEqual(second.duration, 7285)
    }

    func testParsesRealTalkShowSampleFeed() throws {
        guard let fixtureURL = Bundle.module.url(
            forResource: "the-talk-show-feed-sample",
            withExtension: "xml",
            subdirectory: "Fixtures"
        ) else {
            return XCTFail("Missing fixture: the-talk-show-feed-sample.xml")
        }
        let data = try Data(contentsOf: fixtureURL)
        let feedURL = URL(string: "https://daringfireball.net/thetalkshow/rss")!

        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.title, "The Talk Show With John Gruber")
        XCTAssertEqual(podcast.author, "John Gruber")
        XCTAssertEqual(podcast.episodes.count, 2)

        let first = podcast.episodes[0]
        XCTAssertEqual(first.id, "https://daringfireball.net/thetalkshow/2025/12/31/ep-438")
        XCTAssertEqual(first.audioURL?.absoluteString, "https://traffic.libsyn.com/secure/daringfireball/thetalkshow-438-rene-ritchie.mp3")
        XCTAssertEqual(first.duration, 9721)

        let second = podcast.episodes[1]
        XCTAssertEqual(second.id, "https://daringfireball.net/thetalkshow/2025/12/24/ep-437")
        XCTAssertEqual(second.audioURL?.absoluteString, "https://traffic.libsyn.com/secure/daringfireball/thetalkshow-437-quinn-nelson.mp3")
        XCTAssertEqual(second.duration, 8932)
    }

    // MARK: - Categories

    func testParsesCategories() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Test Podcast</title>
            <itunes:category text="Technology"/>
            <itunes:category text="Business"/>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertTrue(podcast.categories.contains("Technology"))
        XCTAssertTrue(podcast.categories.contains("Business"))
    }
}

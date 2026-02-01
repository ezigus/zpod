import Foundation
import XCTest
@testable import FeedParsing
import CoreModels

/// Episode-level parsing coverage (titles, durations, dates, descriptions, artwork).
final class RSSFeedParserEpisodeTests: XCTestCase {

    // MARK: - Basic Episode Parsing

    func testParsesSingleEpisodeWithRequiredFields() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
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

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertEqual(podcast.episodes[0].title, "Episode 1")
        XCTAssertEqual(podcast.episodes[0].id, "ep-001")
        XCTAssertEqual(podcast.episodes[0].audioURL?.absoluteString, "https://example.com/ep1.mp3")
    }

    func testParsesMultipleEpisodes() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
            </item>
            <item>
              <title>Episode 2</title>
              <guid>ep-002</guid>
              <enclosure url="https://example.com/ep2.mp3" type="audio/mpeg"/>
            </item>
            <item>
              <title>Episode 3</title>
              <guid>ep-003</guid>
              <enclosure url="https://example.com/ep3.mp3" type="audio/mpeg"/>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 3)
        XCTAssertEqual(podcast.episodes[0].title, "Episode 1")
        XCTAssertEqual(podcast.episodes[1].title, "Episode 2")
        XCTAssertEqual(podcast.episodes[2].title, "Episode 3")
    }

    // MARK: - Duration Parsing

    func testParsesDurationInSeconds() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <itunes:duration>3600</itunes:duration>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertEqual(podcast.episodes[0].duration, 3600)
    }

    func testParsesDurationInHHMMSS() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <itunes:duration>01:30:00</itunes:duration>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertEqual(podcast.episodes[0].duration, 5400) // 90 minutes = 5400 seconds
    }

    func testParsesDurationInMMSS() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <itunes:duration>45:30</itunes:duration>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertEqual(podcast.episodes[0].duration, 2730) // 45*60 + 30 = 2730 seconds
    }

    func testIgnoresInvalidDuration() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <itunes:duration>01:XX:00</itunes:duration>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertNil(podcast.episodes[0].duration)
    }

    // MARK: - Date Parsing

    func testParsesRFC822Date() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <pubDate>Wed, 15 Jan 2025 10:00:00 GMT</pubDate>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertNotNil(podcast.episodes[0].pubDate)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: podcast.episodes[0].pubDate!)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 0)
    }

    func testParsesISO8601Date() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <pubDate>2025-01-15T10:00:00Z</pubDate>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertNotNil(podcast.episodes[0].pubDate)
    }

    // MARK: - Missing Enclosure

    func testKeepsEpisodeWithoutEnclosure() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
            </item>
            <item>
              <title>Episode 2 - No Audio</title>
              <guid>ep-002</guid>
              <description>This episode has no audio enclosure</description>
            </item>
            <item>
              <title>Episode 3</title>
              <guid>ep-003</guid>
              <enclosure url="https://example.com/ep3.mp3" type="audio/mpeg"/>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 3)
        XCTAssertEqual(podcast.episodes[1].id, "ep-002")
        XCTAssertNil(podcast.episodes[1].audioURL)
    }

    func testLogsWarningForMissingEnclosure() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode Without Audio</title>
              <guid>ep-010</guid>
              <description>No enclosure present in this item.</description>
            </item>
          </channel>
        </rss>
        """
        let warnings = WarningRecorder()
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!

        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL) { @Sendable warning in
            warnings.append(warning)
        }

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertNil(podcast.episodes[0].audioURL)
        XCTAssertTrue(warnings.values.contains { $0.contains("missing audio URL") && $0.contains("Episode Without Audio") })
    }

    func testPreservesDescriptionWithInlineHTML() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <description>Intro <b>bold</b> end</description>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertEqual(podcast.episodes[0].description, "Intro bold end")
    }

    // MARK: - iTunes Summary vs Description

    func testPrefersItunesSummaryOverDescription() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <description>This is the long description with lots of details</description>
              <itunes:summary>Short iTunes summary</itunes:summary>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertEqual(podcast.episodes[0].description, "Short iTunes summary")
    }

    func testUsesDescriptionWhenNoItunesSummary() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <description>Only description available</description>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertEqual(podcast.episodes[0].description, "Only description available")
    }

    // MARK: - Episode Artwork

    func testParsesEpisodeSpecificArtwork() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Test Podcast</title>
            <itunes:image href="https://example.com/podcast-art.jpg"/>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <itunes:image href="https://example.com/ep1-art.jpg"/>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertEqual(podcast.artworkURL?.absoluteString, "https://example.com/podcast-art.jpg")
        XCTAssertEqual(podcast.episodes[0].artworkURL?.absoluteString, "https://example.com/ep1-art.jpg")
    }
}

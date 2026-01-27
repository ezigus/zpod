import Foundation
import XCTest
@testable import FeedParsing
import CoreModels

/// Edge-case handling for malformed or incomplete RSS feeds.
final class RSSFeedParserEdgeCaseTests: XCTestCase {

    func testLogsInvalidEnclosureURLWithoutCrashing() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="ht!tp://bad url" type="audio/mpeg"/>
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
        XCTAssertTrue(warnings.values.contains { $0.contains("invalid audio URL") && $0.contains("ht!tp://bad url") })
        XCTAssertFalse(warnings.values.contains { $0.contains("missing audio URL") })
    }

    func testKeepsFirstValidEnclosureWhenLaterIsInvalid() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
              <enclosure url="ht!tp://bad url" type="audio/mpeg"/>
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
        XCTAssertEqual(podcast.episodes[0].audioURL?.absoluteString, "https://example.com/ep1.mp3")
        XCTAssertTrue(warnings.values.isEmpty)
    }

    func testHandlesEmptyFeed() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Empty Podcast</title>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.title, "Empty Podcast")
        XCTAssertEqual(podcast.episodes.count, 0)
    }

    func testHandlesMissingTitle() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <item>
              <guid>ep-001</guid>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
            </item>
          </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!
        let feedURL = URL(string: "https://example.com/feed.xml")!
        let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: feedURL)

        XCTAssertEqual(podcast.title, "Unknown Podcast")
        XCTAssertEqual(podcast.episodes.count, 1)
        XCTAssertEqual(podcast.episodes[0].title, "Untitled Episode")
    }

    func testGeneratesEpisodeIDWhenGuidMissing() throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode Without GUID</title>
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
        XCTAssertFalse(podcast.episodes[0].id.isEmpty)
        // ID should be generated from title and pubDate
        XCTAssertNotEqual(podcast.episodes[0].id, "Episode Without GUID")
    }
}

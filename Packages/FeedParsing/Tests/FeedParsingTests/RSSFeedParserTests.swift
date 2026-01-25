import Foundation
import XCTest
@testable import FeedParsing
import CoreModels

final class RSSFeedParserTests: XCTestCase {

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

        // Verify the date components in UTC timezone
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

    // MARK: - Comprehensive Integration Test

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

        // Verify podcast metadata
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

    // MARK: - Edge Cases

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

private final class WarningRecorder: @unchecked Sendable {
    private var storage: [String] = []
    private let lock = NSLock()

    func append(_ warning: String) {
        lock.lock()
        storage.append(warning)
        lock.unlock()
    }

    var values: [String] {
        lock.lock()
        let result = storage
        lock.unlock()
        return result
    }
}

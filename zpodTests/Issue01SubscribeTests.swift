import XCTest

@testable import zpod

final class Issue01SubscribeTests: XCTestCase {
  // MARK: - Fixtures
  private let sampleFeedURL = URL(string: "https://example.com/feed.xml")!
  private let sampleFeedXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <channel>
        <title>Sample Podcast</title>
        <description>A sample feed description.</description>
        <itunes:author>Author Name</itunes:author>
        <itunes:image href="https://example.com/image.jpg"/>
        <category>Technology</category>
        <item>
          <guid>ep1-guid</guid>
          <title>Episode One</title>
          <enclosure url="https://example.com/ep1.mp3" length="12345" type="audio/mpeg" />
        </item>
        <item>
          <guid>ep2-guid</guid>
          <title>Episode Two</title>
          <enclosure url="https://example.com/ep2.mp3" length="67890" type="audio/mpeg" />
        </item>
      </channel>
    </rss>
    """.data(using: .utf8)!

  // MARK: - Doubles
  private final class MockDataLoader: FeedDataLoading {
    var responses: [URL: Result<Data, Error>] = [:]
    func load(url: URL) async throws -> Data {
      if let result = responses[url] {
        switch result {
        case .success(let d): return d
        case .failure(let e): throw e
        }
      }
      throw SubscriptionService.Error.dataLoadFailed
    }
  }

  private struct FailingParser: FeedParsing {
    func parse(data: Data, sourceURL: URL) throws -> ParsedFeed {
      throw SubscriptionService.Error.parseFailed
    }
  }

  // MARK: - Tests
  func testSubscribeAddsPodcastAndEpisodes() async throws {
    let manager = InMemoryPodcastManager()
    let loader = MockDataLoader()
    loader.responses[sampleFeedURL] = .success(sampleFeedXML)
    let parser = RSSFeedParser()
    let service = SubscriptionService(dataLoader: loader, parser: parser, podcastManager: manager)

    let podcast = try await service.subscribe(feedURL: sampleFeedURL)
    XCTAssertEqual(podcast.title, "Sample Podcast")
    XCTAssertEqual(podcast.episodes.count, 2)
    XCTAssertTrue(podcast.isSubscribed)
    XCTAssertEqual(manager.all().count, 1)
  }

  func testDuplicateSubscriptionThrows() async throws {
    let manager = InMemoryPodcastManager()
    let loader = MockDataLoader()
    loader.responses[sampleFeedURL] = .success(sampleFeedXML)
    let parser = RSSFeedParser()
    let service = SubscriptionService(dataLoader: loader, parser: parser, podcastManager: manager)

    _ = try await service.subscribe(feedURL: sampleFeedURL)
    do {
      _ = try await service.subscribe(feedURL: sampleFeedURL)
      XCTFail("Expected duplicateSubscription error")
    } catch let error as SubscriptionService.Error {
      XCTAssertEqual(error, .duplicateSubscription)
    }
  }

  func testInvalidURLStringFails() async throws {
    let service = SubscriptionService(
      dataLoader: MockDataLoader(), parser: FailingParser(),
      podcastManager: InMemoryPodcastManager())
    do {
      _ = try await service.subscribe(urlString: "not a url")
      XCTFail("Expected invalidURL error")
    } catch let error as SubscriptionService.Error {
      XCTAssertEqual(error, .invalidURL)
    }
  }

  func testInvalidURLSchemeFails() async throws {
    let service = SubscriptionService(
      dataLoader: MockDataLoader(), parser: FailingParser(),
      podcastManager: InMemoryPodcastManager())

    // Test ftp scheme (not allowed)
    do {
      _ = try await service.subscribe(urlString: "ftp://example.com/feed.xml")
      XCTFail("Expected invalidURL error for ftp scheme")
    } catch let error as SubscriptionService.Error {
      XCTAssertEqual(error, .invalidURL)
    }

    // Test file scheme (not allowed)
    do {
      _ = try await service.subscribe(urlString: "file:///local/feed.xml")
      XCTFail("Expected invalidURL error for file scheme")
    } catch let error as SubscriptionService.Error {
      XCTAssertEqual(error, .invalidURL)
    }
  }

  func testParseFailurePropagates() async throws {
    let manager = InMemoryPodcastManager()
    let loader = MockDataLoader()
    loader.responses[sampleFeedURL] = .success(sampleFeedXML)
    let service = SubscriptionService(
      dataLoader: loader, parser: FailingParser(), podcastManager: manager)
    do {
      _ = try await service.subscribe(feedURL: sampleFeedURL)
      XCTFail("Expected parseFailed error")
    } catch let error as SubscriptionService.Error {
      XCTAssertEqual(error, .parseFailed)
    }
  }

  func testDataLoadFailure() async throws {
    let manager = InMemoryPodcastManager()
    let loader = MockDataLoader()  // no response set
    let parser = RSSFeedParser()
    let service = SubscriptionService(dataLoader: loader, parser: parser, podcastManager: manager)
    do {
      _ = try await service.subscribe(feedURL: sampleFeedURL)
      XCTFail("Expected dataLoadFailed error")
    } catch let error as SubscriptionService.Error {
      XCTAssertEqual(error, .dataLoadFailed)
    }
  }

  func testParserStateResetBetweenCalls() throws {
    let parser = RSSFeedParser()
    let feed1URL = URL(string: "https://example.com/feed1.xml")!
    let feed2URL = URL(string: "https://example.com/feed2.xml")!

    let feed1XML = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
        <channel>
          <title>First Podcast</title>
          <description>First description</description>
          <itunes:author>First Author</itunes:author>
          <item>
            <guid>first-ep-guid</guid>
            <title>First Episode</title>
            <enclosure url="https://example.com/first.mp3" length="1234" type="audio/mpeg" />
          </item>
        </channel>
      </rss>
      """.data(using: .utf8)!

    let feed2XML = """
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
        <channel>
          <title>Second Podcast</title>
          <description>Second description</description>
          <itunes:author>Second Author</itunes:author>
          <item>
            <guid>second-ep-guid</guid>
            <title>Second Episode</title>
            <enclosure url="https://example.com/second.mp3" length="5678" type="audio/mpeg" />
          </item>
        </channel>
      </rss>
      """.data(using: .utf8)!

    // Parse first feed
    let result1 = try parser.parse(data: feed1XML, sourceURL: feed1URL)
    XCTAssertEqual(result1.podcast.title, "First Podcast")
    XCTAssertEqual(result1.podcast.author, "First Author")
    XCTAssertEqual(result1.podcast.episodes.count, 1)
    XCTAssertEqual(result1.podcast.episodes[0].title, "First Episode")

    // Parse second feed - should not contain data from first feed
    let result2 = try parser.parse(data: feed2XML, sourceURL: feed2URL)
    XCTAssertEqual(result2.podcast.title, "Second Podcast")
    XCTAssertEqual(result2.podcast.author, "Second Author")
    XCTAssertEqual(result2.podcast.episodes.count, 1)
    XCTAssertEqual(result2.podcast.episodes[0].title, "Second Episode")

    // Verify no contamination
    XCTAssertNotEqual(result2.podcast.title, "First PodcastSecond Podcast")
    XCTAssertNotEqual(result2.podcast.author, "First AuthorSecond Author")
  }
}

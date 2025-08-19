import XCTest
@testable import zpod

final class Issue11OPMLTests: XCTestCase {
    
    // MARK: - Test Data
    
    private let sampleOPMLXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <opml version="2.0">
        <head>
            <title>My Podcast Subscriptions</title>
            <dateCreated>Wed, 02 Oct 2024 15:00:00 +0000</dateCreated>
            <dateModified>Thu, 03 Oct 2024 10:30:00 +0000</dateModified>
            <ownerName>Test User</ownerName>
        </head>
        <body>
            <outline title="Sample Podcast" xmlUrl="https://example.com/sample.xml" type="rss" text="Sample Podcast" />
            <outline title="Another Podcast" xmlUrl="https://example.com/another.xml" type="rss" text="Another Podcast" />
            <outline title="Tech Folder">
                <outline title="Tech Podcast" xmlUrl="https://example.com/tech.xml" type="rss" text="Tech Podcast" />
            </outline>
        </body>
    </opml>
    """.data(using: .utf8)!
    
    private let sampleRSSXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <channel>
        <title>Sample Podcast</title>
        <description>A sample podcast for testing</description>
        <itunes:author>Sample Author</itunes:author>
        <itunes:image href="https://example.com/artwork.jpg" />
        <item>
          <guid>episode1</guid>
          <title>Episode One</title>
          <enclosure url="https://example.com/ep1.mp3" length="12345" type="audio/mpeg" />
        </item>
      </channel>
    </rss>
    """.data(using: .utf8)!
    
    private let invalidOPMLXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <invalidroot>
        <invalid>content</invalid>
    </invalidroot>
    """.data(using: .utf8)!
    
    // MARK: - OPML Parser Tests
    
    func testParseValidOPML() throws {
        let parser = XMLOPMLParser()
        let document = try parser.parseOPML(data: sampleOPMLXML)
        
        // Verify document structure
        XCTAssertEqual(document.version, "2.0")
        XCTAssertEqual(document.head.title, "My Podcast Subscriptions")
        XCTAssertEqual(document.head.ownerName, "Test User")
        XCTAssertNotNil(document.head.dateCreated)
        XCTAssertNotNil(document.head.dateModified)
        
        // Verify outlines
        XCTAssertEqual(document.body.outlines.count, 3)
        
        // First outline (feed)
        let firstOutline = document.body.outlines[0]
        XCTAssertEqual(firstOutline.title, "Sample Podcast")
        XCTAssertEqual(firstOutline.xmlUrl, "https://example.com/sample.xml")
        XCTAssertEqual(firstOutline.type, "rss")
        XCTAssertTrue(firstOutline.isFeed)
        XCTAssertFalse(firstOutline.isFolder)
        
        // Second outline (feed)
        let secondOutline = document.body.outlines[1]
        XCTAssertEqual(secondOutline.title, "Another Podcast")
        XCTAssertEqual(secondOutline.xmlUrl, "https://example.com/another.xml")
        
        // Third outline (folder with nested feed)
        let folderOutline = document.body.outlines[2]
        XCTAssertEqual(folderOutline.title, "Tech Folder")
        XCTAssertNil(folderOutline.xmlUrl)
        XCTAssertFalse(folderOutline.isFeed)
        XCTAssertTrue(folderOutline.isFolder)
        
        // Nested outline
        let nestedOutlines = folderOutline.outlines!
        XCTAssertEqual(nestedOutlines.count, 1)
        XCTAssertEqual(nestedOutlines[0].title, "Tech Podcast")
        XCTAssertEqual(nestedOutlines[0].xmlUrl, "https://example.com/tech.xml")
    }
    
    func testParseInvalidOPMLThrows() {
        let parser = XMLOPMLParser()
        
        XCTAssertThrowsError(try parser.parseOPML(data: invalidOPMLXML)) { error in
            XCTAssertEqual(error as? XMLOPMLParser.Error, .missingRequiredElements)
        }
    }
    
    func testOPMLOutlineExtractFeedUrls() {
        let parser = XMLOPMLParser()
        var document: OPMLDocument?
        XCTAssertNoThrow(document = try parser.parseOPML(data: sampleOPMLXML))
        guard let document = document else {
            XCTFail("Failed to parse OPML document")
            return
        }
        
        // Extract all feed URLs
        var allUrls: [String] = []
        for outline in document.body.outlines {
            allUrls.append(contentsOf: outline.allFeedUrls())
        }
        
        XCTAssertEqual(allUrls.count, 3)
        XCTAssertTrue(allUrls.contains("https://example.com/sample.xml"))
        XCTAssertTrue(allUrls.contains("https://example.com/another.xml"))
        XCTAssertTrue(allUrls.contains("https://example.com/tech.xml"))
    }
    
    // MARK: - OPML Export Tests
    
    func testExportSubscriptionsCreatesValidOPML() throws {
        let manager = InMemoryPodcastManager()
        let exportService = OPMLExportService(podcastManager: manager)
        
        // Add some subscribed podcasts
        let podcast1 = Podcast(
            id: "https://example.com/feed1.xml",
            title: "Podcast One",
            author: "Author One",
            feedURL: URL(string: "https://example.com/feed1.xml")!,
            isSubscribed: true
        )
        
        let podcast2 = Podcast(
            id: "https://example.com/feed2.xml",
            title: "Podcast Two",
            author: "Author Two",
            feedURL: URL(string: "https://example.com/feed2.xml")!,
            isSubscribed: true
        )
        
        manager.add(podcast1)
        manager.add(podcast2)
        
        let document = try exportService.exportSubscriptions()
        
        // Verify document structure
        XCTAssertEqual(document.version, "2.0")
        XCTAssertEqual(document.head.title, "zPodcastAddict Subscriptions")
        XCTAssertEqual(document.head.ownerName, "zPodcastAddict")
        XCTAssertNotNil(document.head.dateCreated)
        XCTAssertNotNil(document.head.dateModified)
        
        // Verify outlines
        XCTAssertEqual(document.body.outlines.count, 2)
        
        let outline1 = document.body.outlines[0]
        XCTAssertEqual(outline1.title, "Podcast One")
        XCTAssertEqual(outline1.xmlUrl, "https://example.com/feed1.xml")
        XCTAssertEqual(outline1.type, "rss")
        
        let outline2 = document.body.outlines[1]
        XCTAssertEqual(outline2.title, "Podcast Two")
        XCTAssertEqual(outline2.xmlUrl, "https://example.com/feed2.xml")
        XCTAssertEqual(outline2.type, "rss")
    }
    
    func testExportNoSubscriptionsThrows() {
        let manager = InMemoryPodcastManager()
        let exportService = OPMLExportService(podcastManager: manager)
        
        XCTAssertThrowsError(try exportService.exportSubscriptions()) { error in
            XCTAssertEqual(error as? OPMLExportService.Error, .noSubscriptions)
        }
    }
    
    func testExportSubscriptionsAsXML() throws {
        let manager = InMemoryPodcastManager()
        let exportService = OPMLExportService(podcastManager: manager)
        
        let podcast = Podcast(
            id: "https://example.com/feed.xml",
            title: "Test Podcast",
            feedURL: URL(string: "https://example.com/feed.xml")!,
            isSubscribed: true
        )
        
        manager.add(podcast)
        
        let xmlData = try exportService.exportSubscriptionsAsXML()
        let xmlString = String(data: xmlData, encoding: .utf8)!
        
        XCTAssertTrue(xmlString.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(xmlString.contains("<opml version=\"2.0\">"))
        XCTAssertTrue(xmlString.contains("<title>zPodcastAddict Subscriptions</title>"))
        XCTAssertTrue(xmlString.contains("title=\"Test Podcast\""))
        XCTAssertTrue(xmlString.contains("xmlUrl=\"https://example.com/feed.xml\""))
        XCTAssertTrue(xmlString.contains("type=\"rss\""))
    }
    
    // MARK: - OPML Import Tests
    
    func testImportSubscriptionsFromValidOPML() async throws {
        let manager = InMemoryPodcastManager()
        let loader = MockDataLoader()
        
        // Set up mock responses for the feeds in OPML
        loader.responses[URL(string: "https://example.com/sample.xml")!] = .success(sampleRSSXML)
        loader.responses[URL(string: "https://example.com/another.xml")!] = .success(sampleRSSXML)
        loader.responses[URL(string: "https://example.com/tech.xml")!] = .success(sampleRSSXML)
        
        let parser = RSSFeedParser()
        let subscriptionService = SubscriptionService(dataLoader: loader, parser: parser, podcastManager: manager)
        let opmlParser = XMLOPMLParser()
        let importService = OPMLImportService(opmlParser: opmlParser, subscriptionService: subscriptionService)
        
        let result = try await importService.importSubscriptions(from: sampleOPMLXML)
        
        XCTAssertTrue(result.isCompleteSuccess)
        XCTAssertEqual(result.totalFeeds, 3)
        XCTAssertEqual(result.successfulFeeds.count, 3)
        XCTAssertEqual(result.failedFeeds.count, 0)
        
        XCTAssertTrue(result.successfulFeeds.contains("https://example.com/sample.xml"))
        XCTAssertTrue(result.successfulFeeds.contains("https://example.com/another.xml"))
        XCTAssertTrue(result.successfulFeeds.contains("https://example.com/tech.xml"))
        
        // Verify podcasts were actually added to manager
        XCTAssertEqual(manager.all().count, 3)
    }
    
    func testImportSubscriptionsWithDuplicatesHandled() async throws {
        let manager = InMemoryPodcastManager()
        let loader = MockDataLoader()
        
        // Set up mock responses
        loader.responses[URL(string: "https://example.com/sample.xml")!] = .success(sampleRSSXML)
        loader.responses[URL(string: "https://example.com/another.xml")!] = .success(sampleRSSXML)
        loader.responses[URL(string: "https://example.com/tech.xml")!] = .success(sampleRSSXML)
        
        let parser = RSSFeedParser()
        let subscriptionService = SubscriptionService(dataLoader: loader, parser: parser, podcastManager: manager)
        let opmlParser = XMLOPMLParser()
        let importService = OPMLImportService(opmlParser: opmlParser, subscriptionService: subscriptionService)
        
        // First import should succeed
        let result1 = try await importService.importSubscriptions(from: sampleOPMLXML)
        XCTAssertTrue(result1.isCompleteSuccess)
        XCTAssertEqual(result1.successfulFeeds.count, 3)
        
        // Second import should handle duplicates gracefully
        let result2 = try await importService.importSubscriptions(from: sampleOPMLXML)
        XCTAssertFalse(result2.isCompleteSuccess)
        XCTAssertEqual(result2.successfulFeeds.count, 0)
        XCTAssertEqual(result2.failedFeeds.count, 3)
        
        // All failures should be duplicate subscription errors
        for (_, error) in result2.failedFeeds {
            XCTAssertEqual(error, "Already subscribed")
        }
    }
    
    func testImportSubscriptionsWithPartialFailures() async throws {
        let manager = InMemoryPodcastManager()
        let loader = MockDataLoader()
        
        // Set up partial mock responses (some succeed, some fail)
        loader.responses[URL(string: "https://example.com/sample.xml")!] = .success(sampleRSSXML)
        loader.responses[URL(string: "https://example.com/another.xml")!] = .failure(SubscriptionService.Error.dataLoadFailed)
        loader.responses[URL(string: "https://example.com/tech.xml")!] = .success(sampleRSSXML)
        
        let parser = RSSFeedParser()
        let subscriptionService = SubscriptionService(dataLoader: loader, parser: parser, podcastManager: manager)
        let opmlParser = XMLOPMLParser()
        let importService = OPMLImportService(opmlParser: opmlParser, subscriptionService: subscriptionService)
        
        let result = try await importService.importSubscriptions(from: sampleOPMLXML)
        
        XCTAssertFalse(result.isCompleteSuccess)
        XCTAssertTrue(result.hasPartialSuccess)
        XCTAssertEqual(result.totalFeeds, 3)
        XCTAssertEqual(result.successfulFeeds.count, 2)
        XCTAssertEqual(result.failedFeeds.count, 1)
        
        XCTAssertTrue(result.successfulFeeds.contains("https://example.com/sample.xml"))
        XCTAssertTrue(result.successfulFeeds.contains("https://example.com/tech.xml"))
        
        let (failedUrl, failedError) = result.failedFeeds[0]
        XCTAssertEqual(failedUrl, "https://example.com/another.xml")
        XCTAssertEqual(failedError, "Failed to load feed data")
    }
    
    func testImportInvalidOPMLThrows() async {
        let manager = InMemoryPodcastManager()
        let loader = MockDataLoader()
        let parser = RSSFeedParser()
        let subscriptionService = SubscriptionService(dataLoader: loader, parser: parser, podcastManager: manager)
        let opmlParser = XMLOPMLParser()
        let importService = OPMLImportService(opmlParser: opmlParser, subscriptionService: subscriptionService)
        
        do {
            _ = try await importService.importSubscriptions(from: invalidOPMLXML)
            XCTFail("Expected invalidOPML error")
        } catch let error as OPMLImportService.Error {
            XCTAssertEqual(error, .invalidOPML)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Round-trip Tests
    
    func testRoundTripExportImport() async throws {
        let manager = InMemoryPodcastManager()
        let loader = MockDataLoader()
        
        // Add some podcasts to export
        let podcast1 = Podcast(
            id: "https://example.com/podcast1.xml",
            title: "Podcast One",
            author: "Author One",
            feedURL: URL(string: "https://example.com/podcast1.xml")!,
            isSubscribed: true
        )
        
        let podcast2 = Podcast(
            id: "https://example.com/podcast2.xml",
            title: "Podcast Two",
            author: "Author Two",
            feedURL: URL(string: "https://example.com/podcast2.xml")!,
            isSubscribed: true
        )
        
        manager.add(podcast1)
        manager.add(podcast2)
        
        // Export to OPML
        let exportService = OPMLExportService(podcastManager: manager)
        let exportedXML = try exportService.exportSubscriptionsAsXML()
        
        // Set up fresh manager and import services
        let importManager = InMemoryPodcastManager()
        loader.responses[URL(string: "https://example.com/podcast1.xml")!] = .success(sampleRSSXML)
        loader.responses[URL(string: "https://example.com/podcast2.xml")!] = .success(sampleRSSXML)
        
        let parser = RSSFeedParser()
        let subscriptionService = SubscriptionService(dataLoader: loader, parser: parser, podcastManager: importManager)
        let opmlParser = XMLOPMLParser()
        let importService = OPMLImportService(opmlParser: opmlParser, subscriptionService: subscriptionService)
        
        // Import the exported OPML
        let result = try await importService.importSubscriptions(from: exportedXML)
        
        XCTAssertTrue(result.isCompleteSuccess)
        XCTAssertEqual(result.totalFeeds, 2)
        XCTAssertEqual(result.successfulFeeds.count, 2)
        
        // Verify imported podcasts have the correct feed URLs
        let importedPodcasts = importManager.all()
        XCTAssertEqual(importedPodcasts.count, 2)
        
        let importedUrls = Set(importedPodcasts.map { $0.feedURL.absoluteString })
        XCTAssertTrue(importedUrls.contains("https://example.com/podcast1.xml"))
        XCTAssertTrue(importedUrls.contains("https://example.com/podcast2.xml"))
    }
    
    // MARK: - Test Doubles
    
    private final class MockDataLoader: FeedDataLoading {
        var responses: [URL: Result<Data, Error>] = [:]
        
        func load(url: URL) async throws -> Data {
            if let result = responses[url] {
                switch result {
                case .success(let data):
                    return data
                case .failure(let error):
                    throw error
                }
            }
            throw SubscriptionService.Error.dataLoadFailed
        }
    }
}

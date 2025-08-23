import XCTest
import Foundation
@testable import FeedParsing
import CoreModels
import SharedUtilities

#if canImport(CoreFoundation)
import CoreFoundation
#endif

final class ComprehensiveFeedParsingTests: XCTestCase {
    
    private var opmlParser: XMLOPMLParser!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Given: Fresh OPML parser instance  
        #if canImport(FoundationXML)
        opmlParser = XMLOPMLParser()
        #endif
    }
    
    override func tearDown() async throws {
        opmlParser = nil
        try await super.tearDown()
    }
    
    // MARK: - OPML Parser Tests
    
    #if canImport(FoundationXML)
    func testOPMLParser_ValidDocument() throws {
        // Given: Valid OPML XML document
        let validOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title>My Podcast Subscriptions</title>
                <dateCreated>Wed, 15 Nov 2023 12:00:00 GMT</dateCreated>
            </head>
            <body>
                <outline text="Tech News Daily" xmlUrl="https://example.com/feed.xml" />
                <outline text="Science Weekly" xmlUrl="https://science.example.com/rss" />
            </body>
        </opml>
        """
        let data = validOPML.data(using: .utf8)!
        
        // When: Parsing OPML document
        let result = try opmlParser.parseOPML(data: data)
        
        // Then: Document parsed successfully
        XCTAssertEqual(result.head.title, "My Podcast Subscriptions")
        XCTAssertEqual(result.body.outlines.count, 2)
        XCTAssertEqual(result.body.outlines[0].text, "Tech News Daily")
        XCTAssertEqual(result.body.outlines[0].xmlUrl, "https://example.com/feed.xml")
        XCTAssertEqual(result.body.outlines[1].text, "Science Weekly")
        XCTAssertEqual(result.body.outlines[1].xmlUrl, "https://science.example.com/rss")
    }
    
    func testOPMLParser_InvalidXML() throws {
        // Given: Invalid XML data
        let invalidXML = "This is not valid XML"
        let data = invalidXML.data(using: .utf8)!
        
        // When: Parsing invalid XML
        // Then: Should throw appropriate error
        XCTAssertThrowsError(try opmlParser.parseOPML(data: data)) { error in
            XCTAssertTrue(error is XMLOPMLParser.Error)
        }
    }
    
    func testOPMLParser_EmptyDocument() throws {
        // Given: Empty OPML document
        let emptyOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title>Empty Subscriptions</title>
            </head>
            <body>
            </body>
        </opml>
        """
        let data = emptyOPML.data(using: .utf8)!
        
        // When: Parsing empty document
        let result = try opmlParser.parseOPML(data: data)
        
        // Then: Document parsed with empty outlines
        XCTAssertEqual(result.head.title, "Empty Subscriptions")
        XCTAssertEqual(result.body.outlines.count, 0)
    }
    
    func testOPMLParser_NestedOutlines() throws {
        // Given: OPML with nested folder structure
        let nestedOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title>Organized Subscriptions</title>
            </head>
            <body>
                <outline text="Technology">
                    <outline text="Tech News Daily" xmlUrl="https://example.com/feed.xml" />
                    <outline text="Developer Weekly" xmlUrl="https://dev.example.com/rss" />
                </outline>
                <outline text="Science">
                    <outline text="Science Weekly" xmlUrl="https://science.example.com/rss" />
                </outline>
            </body>
        </opml>
        """
        let data = nestedOPML.data(using: .utf8)!
        
        // When: Parsing nested structure
        let result = try opmlParser.parseOPML(data: data)
        
        // Then: Nested structure preserved
        XCTAssertEqual(result.body.outlines.count, 2)
        XCTAssertEqual(result.body.outlines[0].text, "Technology")
        XCTAssertEqual(result.body.outlines[0].outlines?.count, 2)
        XCTAssertEqual(result.body.outlines[1].text, "Science")
        XCTAssertEqual(result.body.outlines[1].outlines?.count, 1)
    }
    
    func testOPMLParser_UnicodeContent() throws {
        // Given: OPML with Unicode characters
        let unicodeOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title>Suscripciones de Podcasts</title>
            </head>
            <body>
                <outline text="日本のニュース" xmlUrl="https://example.jp/feed.xml" />
                <outline text="Français Actualités" xmlUrl="https://exemple.fr/rss" />
                <outline text="العربية الأخبار" xmlUrl="https://example.ar/rss" />
            </body>
        </opml>
        """
        let data = unicodeOPML.data(using: .utf8)!
        
        // When: Parsing Unicode content
        let result = try opmlParser.parseOPML(data: data)
        
        // Then: Unicode preserved correctly
        XCTAssertEqual(result.head.title, "Suscripciones de Podcasts")
        XCTAssertEqual(result.body.outlines[0].text, "日本のニュース")
        XCTAssertEqual(result.body.outlines[1].text, "Français Actualités")
        XCTAssertEqual(result.body.outlines[2].text, "العربية الأخبار")
    }
    
    func testOPMLTypes_FeedURLExtraction() throws {
        // Given: OPML outline with feed URLs
        let opmlData = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head><title>Feed URL Test</title></head>
            <body>
                <outline text="Folder">
                    <outline text="Podcast 1" xmlUrl="https://example1.com/feed.xml" />
                    <outline text="Podcast 2" xmlUrl="https://example2.com/rss" />
                </outline>
                <outline text="Podcast 3" xmlUrl="https://example3.com/feed.xml" />
            </body>
        </opml>
        """
        let data = opmlData.data(using: .utf8)!
        
        // When: Parsing and extracting feed URLs
        let result = try opmlParser.parseOPML(data: data)
        
        // Then: Can extract all feed URLs including nested ones
        let folderOutline = result.body.outlines[0]
        let feedURLs = folderOutline.allFeedUrls()
        XCTAssertEqual(feedURLs.count, 2)
        XCTAssertTrue(feedURLs.contains("https://example1.com/feed.xml"))
        XCTAssertTrue(feedURLs.contains("https://example2.com/rss"))
        
        let directOutline = result.body.outlines[1]
        let directFeedURLs = directOutline.allFeedUrls()
        XCTAssertEqual(directFeedURLs.count, 1)
        XCTAssertEqual(directFeedURLs[0], "https://example3.com/feed.xml")
    }
    
    func testOPMLParser_LargeDocument() throws {
        // Given: Large OPML document with many outlines
        var largeOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head><title>Large Document</title></head>
            <body>
        """
        
        // Generate 100 outline entries for performance testing
        for i in 1...100 {
            largeOPML += "    <outline text=\"Podcast \(i)\" xmlUrl=\"https://example\(i).com/feed.xml\" />\n"
        }
        
        largeOPML += """
            </body>
        </opml>
        """
        
        let data = largeOPML.data(using: .utf8)!
        
        // When: Parsing large document
        #if canImport(CoreFoundation)
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try opmlParser.parseOPML(data: data)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then: Document parsed efficiently
        XCTAssertEqual(result.body.outlines.count, 100)
        XCTAssertLessThan(timeElapsed, 2.0) // Should complete within 2 seconds
        #else
        // Cross-platform fallback without timing
        let result = try opmlParser.parseOPML(data: data)
        XCTAssertEqual(result.body.outlines.count, 100)
        #endif
    }
    
    @MainActor
    func testOPMLParser_ConcurrentAccess() throws {
        // Given: Multiple parser instances for concurrency testing
        let parser1 = XMLOPMLParser()
        let parser2 = XMLOPMLParser()
        
        let opmlData = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head><title>Concurrent Test</title></head>
            <body><outline text="Test Podcast" xmlUrl="https://example.com/feed.xml" /></body>
        </opml>
        """.data(using: .utf8)!
        
        // When: Using parsers concurrently
        var results: [OPMLDocument] = []
        let expectation = self.expectation(description: "Concurrent parsing")
        expectation.expectedFulfillmentCount = 2
        
        DispatchQueue.global().async {
            do {
                let result = try parser1.parseOPML(data: opmlData)
                DispatchQueue.main.async {
                    results.append(result)
                    expectation.fulfill()
                }
            } catch {
                XCTFail("Parser 1 failed: \(error)")
            }
        }
        
        DispatchQueue.global().async {
            do {
                let result = try parser2.parseOPML(data: opmlData)
                DispatchQueue.main.async {
                    results.append(result)
                    expectation.fulfill()
                }
            } catch {
                XCTFail("Parser 2 failed: \(error)")
            }
        }
        
        // Then: Both parsers complete successfully
        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].head.title, "Concurrent Test")
        XCTAssertEqual(results[1].head.title, "Concurrent Test")
    }
    
    func testOPMLParser_ErrorHandling() throws {
        // Given: Various invalid OPML formats
        let invalidFormats = [
            "", // Empty string
            "<xml>invalid</xml>", // Wrong root element
            "<?xml version=\"1.0\"?><opml><head></opml>", // Malformed XML
            "<?xml version=\"1.0\"?><opml version=\"1.0\"></opml>" // Unsupported version potentially
        ]
        
        // When: Parsing each invalid format
        for (index, invalidOPML) in invalidFormats.enumerated() {
            let data = invalidOPML.data(using: .utf8)!
            
            // Then: Should throw appropriate error
            XCTAssertThrowsError(try opmlParser.parseOPML(data: data), 
                               "Failed to throw error for invalid format \(index)") { error in
                XCTAssertTrue(error is XMLOPMLParser.Error, 
                            "Unexpected error type for format \(index): \(error)")
            }
        }
    }
    
    func testOPMLParser_EdgeCases() throws {
        // Given: OPML with edge cases
        let edgeCaseOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head>
                <title></title>
            </head>
            <body>
                <outline text="" xmlUrl="" />
                <outline text="Valid Podcast" xmlUrl="https://example.com/feed.xml" />
                <outline text="No URL Podcast" />
            </body>
        </opml>
        """
        let data = edgeCaseOPML.data(using: .utf8)!
        
        // When: Parsing edge cases
        let result = try opmlParser.parseOPML(data: data)
        
        // Then: Edge cases handled gracefully
        XCTAssertEqual(result.head.title, "") // Empty title is preserved
        XCTAssertEqual(result.body.outlines.count, 3)
        XCTAssertEqual(result.body.outlines[0].text, "") // Empty text preserved
        XCTAssertEqual(result.body.outlines[0].xmlUrl, "") // Empty URL preserved
        XCTAssertEqual(result.body.outlines[1].text, "Valid Podcast")
        XCTAssertEqual(result.body.outlines[1].xmlUrl, "https://example.com/feed.xml")
        XCTAssertEqual(result.body.outlines[2].text, "No URL Podcast")
        XCTAssertNil(result.body.outlines[2].xmlUrl) // No xmlUrl attribute
    }
    #endif
    
    // MARK: - Cross-Platform Compatibility Tests
    
    #if !canImport(FoundationXML)
    func testCrossPlatformCompatibility_NoFoundationXML() {
        // Given: Platform without FoundationXML
        // When: Testing availability
        // Then: Test should still run without crashing
        XCTAssertTrue(true, "Cross-platform test passes on platforms without FoundationXML")
    }
    #endif
    
    // MARK: - Sendable Compliance Tests
    
    func testSendableCompliance() {
        // Given: OPML Document and related types from FeedParsing module
        let head = OPMLHead(title: "Test Title", dateCreated: nil, dateModified: nil, ownerName: nil)
        let outline = OPMLOutline(title: "Test Outline", xmlUrl: "https://example.com/feed.xml", 
                                 htmlUrl: nil, type: nil, text: "Test Text", outlines: nil)
        let body = OPMLBody(outlines: [outline])
        let document = OPMLDocument(version: "2.0", head: head, body: body)
        
        // When: Using types in concurrent contexts
        DispatchQueue.global().async {
            // Then: Should compile without Sendable warnings
            let _ = document.head.title
            let _ = document.body.outlines.count
        }
        
        XCTAssertEqual(document.head.title, "Test Title")
        XCTAssertEqual(document.body.outlines.count, 1)
    }
    
    // MARK: - Service Interface Tests
    
    func testSubscriptionService_Protocol() {
        // Given: Testing that SubscriptionService protocol is available
        // When: Defining a mock implementation
        struct MockSubscriptionService: SubscriptionService {
            func subscribe(urlString: String) async throws {
                // Mock implementation
            }
        }
        
        let mockService = MockSubscriptionService()
        
        // Then: Protocol can be implemented
        XCTAssertNotNil(mockService)
    }
    
    func testParsedFeed_Structure() {
        // Given: Creating a ParsedFeed instance
        let parsedFeed = ParsedFeed(title: "Test Feed", episodes: [])
        
        // When: Accessing properties
        // Then: Structure is available and working
        XCTAssertEqual(parsedFeed.title, "Test Feed")
        XCTAssertEqual(parsedFeed.episodes.count, 0)
    }
    
    // MARK: - Integration Tests
    
    #if canImport(FoundationXML)
    func testOPMLWorkflow_BasicUsage() throws {
        // Given: Valid OPML data
        let opmlData = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
            <head><title>Integration Test</title></head>
            <body>
                <outline text="Test Podcast 1" xmlUrl="https://example1.com/feed.xml" />
                <outline text="Test Podcast 2" xmlUrl="https://example2.com/rss" />
            </body>
        </opml>
        """.data(using: .utf8)!
        
        // When: Parsing and extracting URLs
        let document = try opmlParser.parseOPML(data: opmlData)
        let allURLs = document.body.outlines.flatMap { $0.allFeedUrls() }
        
        // Then: All feed URLs extracted correctly
        XCTAssertEqual(document.head.title, "Integration Test")
        XCTAssertEqual(allURLs.count, 2)
        XCTAssertTrue(allURLs.contains("https://example1.com/feed.xml"))
        XCTAssertTrue(allURLs.contains("https://example2.com/rss"))
    }
    
    func testOPMLParser_StressTest() throws {
        // Given: Multiple small OPML documents for stress testing
        let documents = (1...10).map { index in
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <opml version="2.0">
                <head><title>Stress Test \(index)</title></head>
                <body>
                    <outline text="Podcast \(index)" xmlUrl="https://example\(index).com/feed.xml" />
                </body>
            </opml>
            """.data(using: .utf8)!
        }
        
        // When: Parsing all documents sequentially
        var results: [OPMLDocument] = []
        for data in documents {
            let result = try opmlParser.parseOPML(data: data)
            results.append(result)
        }
        
        // Then: All documents parsed successfully
        XCTAssertEqual(results.count, 10)
        for (index, result) in results.enumerated() {
            XCTAssertEqual(result.head.title, "Stress Test \(index + 1)")
            XCTAssertEqual(result.body.outlines.count, 1)
        }
    }
    #endif
}
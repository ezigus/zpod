import XCTest
import Foundation
import CoreModels
@testable import SearchDomain

// MARK: - Mock URLSession support

private final class MockURLProtocol: URLProtocol {
    // Access is serialized by test setUp/tearDown; nonisolated(unsafe) suppresses
    // the Swift 6 global-mutable-state error for this test-only helper.
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLSession {
    static func mock() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - Tests

final class ITunesSearchProviderTests: XCTestCase {

    private var session: URLSession!
    private var provider: ITunesSearchProvider!

    override func setUp() {
        super.setUp()
        session = .mock()
        provider = ITunesSearchProvider(urlSession: session)
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        session = nil
        provider = nil
        super.tearDown()
    }

    // MARK: - Happy path

    func testSearch_ReturnsParsedResults() async throws {
        MockURLProtocol.handler = { _ in
            let json = Self.sampleResponse
            let response = HTTPURLResponse(url: URL(string: "https://itunes.apple.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let results = try await provider.search(query: "Swift Talk", limit: 5)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Swift Talk")
        XCTAssertEqual(results[0].author, "objc.io")
        XCTAssertEqual(results[0].provider, "itunes")
        XCTAssertEqual(results[0].episodeCount, 300)
        XCTAssertNotNil(results[0].feedURL)
    }

    func testSearch_FiltersResultsWithMissingFeedURL() async throws {
        MockURLProtocol.handler = { _ in
            let json = Self.responseWithMissingFeedURL
            let response = HTTPURLResponse(url: URL(string: "https://itunes.apple.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let results = try await provider.search(query: "anything", limit: 5)
        XCTAssertEqual(results.count, 0, "Results without feedUrl should be filtered out")
    }

    func testSearch_BuildsCorrectURL() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Self.emptyResponse)
        }

        _ = try await provider.search(query: "Hard Fork", limit: 10)

        let url = try XCTUnwrap(capturedRequest?.url)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        let dict = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        XCTAssertEqual(dict["term"], "Hard Fork")
        XCTAssertEqual(dict["media"], "podcast")
        XCTAssertEqual(dict["limit"], "10")
    }

    // MARK: - Error handling

    func testSearch_ThrowsInvalidQuery_WhenEmpty() async {
        do {
            _ = try await provider.search(query: "   ", limit: 5)
            XCTFail("Expected DirectorySearchError.invalidQuery")
        } catch DirectorySearchError.invalidQuery {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearch_ThrowsHTTPError_OnNon200() async {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await provider.search(query: "test", limit: 5)
            XCTFail("Expected DirectorySearchError.httpError")
        } catch DirectorySearchError.httpError(let code) {
            XCTAssertEqual(code, 429)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearch_ThrowsDecodingError_OnInvalidJSON() async {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("not json".utf8))
        }

        do {
            _ = try await provider.search(query: "test", limit: 5)
            XCTFail("Expected DirectorySearchError.decodingError")
        } catch DirectorySearchError.decodingError {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearch_ThrowsNetworkError_OnConnectionFailure() async {
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await provider.search(query: "test", limit: 5)
            XCTFail("Expected DirectorySearchError.networkError")
        } catch DirectorySearchError.networkError {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - DirectorySearchResult.toPodcast

    func testToPodcast_MapsFieldsCorrectly() {
        let result = DirectorySearchResult(
            id: "123",
            title: "My Podcast",
            author: "Author",
            description: "Desc",
            artworkURL: URL(string: "https://example.com/art.jpg"),
            feedURL: URL(string: "https://example.com/feed.xml")!,
            genres: ["Technology"],
            episodeCount: 50,
            provider: "itunes"
        )

        let podcast = result.toPodcast()
        XCTAssertEqual(podcast.title, "My Podcast")
        XCTAssertEqual(podcast.author, "Author")
        XCTAssertEqual(podcast.feedURL.absoluteString, "https://example.com/feed.xml")
        XCTAssertFalse(podcast.isSubscribed)
        XCTAssertEqual(podcast.categories, ["Technology"])
    }

    // MARK: - Sample JSON fixtures

    private static let sampleResponse: Data = """
    {
        "resultCount": 1,
        "results": [
            {
                "collectionId": 12345,
                "collectionName": "Swift Talk",
                "artistName": "objc.io",
                "artworkUrl600": "https://example.com/art.jpg",
                "feedUrl": "https://example.com/feed.xml",
                "primaryGenreName": "Technology",
                "genres": ["Technology", "Swift"],
                "trackCount": 300,
                "kind": "podcast"
            }
        ]
    }
    """.data(using: .utf8)!

    private static let responseWithMissingFeedURL: Data = """
    {
        "resultCount": 1,
        "results": [
            {
                "collectionId": 99,
                "collectionName": "No Feed Podcast",
                "artistName": "Nobody",
                "kind": "podcast"
            }
        ]
    }
    """.data(using: .utf8)!

    private static let emptyResponse: Data = """
    { "resultCount": 0, "results": [] }
    """.data(using: .utf8)!
}

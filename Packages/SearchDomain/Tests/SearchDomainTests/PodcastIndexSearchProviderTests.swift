import XCTest
import Foundation
import CoreModels
@testable import SearchDomain

// MARK: - Mock URLSession support (separate from ITunesSearchProviderTests to avoid private redeclaration)

private final class PIMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = PIMockURLProtocol.handler else {
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
    static func piMock() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PIMockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - Tests

final class PodcastIndexSearchProviderTests: XCTestCase {

    private var session: URLSession!

    override func setUp() {
        super.setUp()
        session = .piMock()
    }

    override func tearDown() {
        PIMockURLProtocol.handler = nil
        session = nil
        super.tearDown()
    }

    // MARK: - Failable init

    func testInit_ReturnsNil_WhenApiKeyIsNil() {
        let provider = PodcastIndexSearchProvider(apiKey: nil, apiSecret: "secret")
        XCTAssertNil(provider, "Should return nil when apiKey is nil")
    }

    func testInit_ReturnsNil_WhenApiSecretIsNil() {
        let provider = PodcastIndexSearchProvider(apiKey: "key", apiSecret: nil)
        XCTAssertNil(provider, "Should return nil when apiSecret is nil")
    }

    func testInit_ReturnsNil_WhenApiKeyIsEmpty() {
        let provider = PodcastIndexSearchProvider(apiKey: "", apiSecret: "secret")
        XCTAssertNil(provider, "Should return nil when apiKey is empty")
    }

    func testInit_ReturnsNil_WhenBothKeysAreNil() {
        let provider = PodcastIndexSearchProvider(apiKey: nil, apiSecret: nil)
        XCTAssertNil(provider)
    }

    func testInit_Succeeds_WithValidKeys() {
        let provider = PodcastIndexSearchProvider(apiKey: "key", apiSecret: "secret", urlSession: session)
        XCTAssertNotNil(provider)
    }

    func testInit_GivenEmptyAPISecret_ReturnsNil() {
        // Given: valid key but empty secret
        let provider = PodcastIndexSearchProvider(apiKey: "valid-key", apiSecret: "")

        // Then: init fails — empty secret is equivalent to missing credentials
        XCTAssertNil(provider, "PodcastIndexSearchProvider should return nil for empty apiSecret")
    }

    // MARK: - Happy path

    func testSearch_ReturnsParsedResults() async throws {
        let provider = try XCTUnwrap(PodcastIndexSearchProvider(apiKey: "key", apiSecret: "secret", urlSession: session))

        PIMockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(url: URL(string: "https://api.podcastindex.org")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Self.sampleResponse)
        }

        let results = try await provider.search(query: "Swift Talk", limit: 5)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Swift Talk")
        XCTAssertEqual(results[0].author, "objc.io")
        XCTAssertEqual(results[0].provider, "podcastindex")
        XCTAssertEqual(results[0].episodeCount, 250)
        XCTAssertNotNil(results[0].feedURL)
    }

    func testSearch_FiltersResultsWithMissingFeedURL() async throws {
        let provider = try XCTUnwrap(PodcastIndexSearchProvider(apiKey: "key", apiSecret: "secret", urlSession: session))

        PIMockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(url: URL(string: "https://api.podcastindex.org")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Self.responseWithMissingURL)
        }

        let results = try await provider.search(query: "anything", limit: 5)
        XCTAssertEqual(results.count, 0, "Feeds without url should be filtered out")
    }

    // MARK: - Auth headers

    func testSearch_SendsAuthHeaders() async throws {
        let provider = try XCTUnwrap(PodcastIndexSearchProvider(apiKey: "testkey", apiSecret: "testsecret", urlSession: session))

        var capturedRequest: URLRequest?
        PIMockURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Self.emptyResponse)
        }

        _ = try await provider.search(query: "test", limit: 5)

        let req = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Auth-Key"), "testkey")
        XCTAssertNotNil(req.value(forHTTPHeaderField: "X-Auth-Date"), "X-Auth-Date must be set")
        XCTAssertNotNil(req.value(forHTTPHeaderField: "Authorization"), "Authorization must be set")
        XCTAssertEqual(req.value(forHTTPHeaderField: "User-Agent"), "zpod/1.0")
    }

    func testSearch_AuthorizationHeader_Is40CharHex() async throws {
        let provider = try XCTUnwrap(PodcastIndexSearchProvider(apiKey: "k", apiSecret: "s", urlSession: session))

        var capturedRequest: URLRequest?
        PIMockURLProtocol.handler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Self.emptyResponse)
        }

        _ = try await provider.search(query: "test", limit: 5)

        let auth = try XCTUnwrap(capturedRequest?.value(forHTTPHeaderField: "Authorization"))
        // SHA-1 produces 20 bytes = 40 hex characters
        XCTAssertEqual(auth.count, 40, "Authorization should be a 40-character SHA-1 hex digest")
        XCTAssertTrue(auth.allSatisfy { $0.isHexDigit }, "Authorization must contain only hex digits")
    }

    // MARK: - Error handling

    func testSearch_ThrowsInvalidQuery_WhenEmpty() async throws {
        let provider = try XCTUnwrap(PodcastIndexSearchProvider(apiKey: "key", apiSecret: "secret", urlSession: session))

        do {
            _ = try await provider.search(query: "   ", limit: 5)
            XCTFail("Expected DirectorySearchError.invalidQuery")
        } catch DirectorySearchError.invalidQuery {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearch_ThrowsHTTPError_On401() async throws {
        let provider = try XCTUnwrap(PodcastIndexSearchProvider(apiKey: "key", apiSecret: "secret", urlSession: session))

        PIMockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await provider.search(query: "test", limit: 5)
            XCTFail("Expected DirectorySearchError.httpError")
        } catch DirectorySearchError.httpError(let code) {
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSearch_ThrowsHTTPError_On429() async throws {
        let provider = try XCTUnwrap(PodcastIndexSearchProvider(apiKey: "key", apiSecret: "secret", urlSession: session))

        PIMockURLProtocol.handler = { request in
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

    func testSearch_ThrowsDecodingError_OnInvalidJSON() async throws {
        let provider = try XCTUnwrap(PodcastIndexSearchProvider(apiKey: "key", apiSecret: "secret", urlSession: session))

        PIMockURLProtocol.handler = { request in
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

    func testSearch_ThrowsNetworkError_OnConnectionFailure() async throws {
        let provider = try XCTUnwrap(PodcastIndexSearchProvider(apiKey: "key", apiSecret: "secret", urlSession: session))

        PIMockURLProtocol.handler = { _ in
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

    func testSearch_GivenStatusFalseResponse_ThrowsHTTPError401() async throws {
        // Given: PodcastIndex returns HTTP 200 with status:"false" (auth failure)
        let statusFalseJSON = """
        {"status":"false","description":"Invalid API key","feeds":[],"count":0}
        """.data(using: .utf8)!

        PIMockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, statusFalseJSON)
        }

        let provider = try XCTUnwrap(PodcastIndexSearchProvider(apiKey: "test-key", apiSecret: "test-secret", urlSession: session))

        // When / Then: throws .httpError(401)
        do {
            _ = try await provider.search(query: "swift", limit: 5)
            XCTFail("Expected httpError(401) but no error was thrown")
        } catch DirectorySearchError.httpError(let code) {
            XCTAssertEqual(code, 401, "Status-false response should map to httpError(401)")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Sample JSON fixtures

    private static let sampleResponse: Data = """
    {
        "status": "true",
        "feeds": [
            {
                "id": 99999,
                "title": "Swift Talk",
                "author": "objc.io",
                "description": "A weekly video series on Swift programming.",
                "artwork": "https://example.com/art.jpg",
                "url": "https://example.com/feed.xml",
                "categories": {"1": "Technology"},
                "episodeCount": 250
            }
        ],
        "count": 1
    }
    """.data(using: .utf8)!

    private static let responseWithMissingURL: Data = """
    {
        "status": "true",
        "feeds": [
            {
                "id": 1,
                "title": "No URL Podcast",
                "author": "Nobody",
                "episodeCount": 10
            }
        ],
        "count": 1
    }
    """.data(using: .utf8)!

    private static let emptyResponse: Data = """
    { "status": "true", "feeds": [], "count": 0 }
    """.data(using: .utf8)!
}

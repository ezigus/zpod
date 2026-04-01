import XCTest
import Foundation
import CoreModels
@testable import SearchDomain

// MARK: - Mock provider

private final class MockSearchProvider: PodcastDirectorySearching, @unchecked Sendable {
    let results: [DirectorySearchResult]
    let error: (any Error)?

    init(results: [DirectorySearchResult] = [], error: (any Error)? = nil) {
        self.results = results
        self.error = error
    }

    func search(query: String, limit: Int) async throws -> [DirectorySearchResult] {
        if let error { throw error }
        return results
    }
}

private func makeResult(feedURL: String, title: String, provider: String = "mock") -> DirectorySearchResult {
    DirectorySearchResult(
        id: feedURL,
        title: title,
        author: nil,
        description: nil,
        artworkURL: nil,
        feedURL: URL(string: feedURL)!,
        genres: [],
        episodeCount: nil,
        provider: provider
    )
}

// MARK: - Tests

final class AggregateSearchProviderTests: XCTestCase {

    // MARK: - Empty providers

    func testSearch_ReturnsEmpty_WhenNoProviders() async throws {
        let aggregate = AggregateSearchProvider(providers: [])
        let results = try await aggregate.search(query: "test", limit: 10)
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Merged results

    func testSearch_MergesResultsFromTwoProviders() async throws {
        let provider1 = MockSearchProvider(results: [
            makeResult(feedURL: "https://a.com/feed", title: "A"),
        ])
        let provider2 = MockSearchProvider(results: [
            makeResult(feedURL: "https://b.com/feed", title: "B"),
        ])
        let aggregate = AggregateSearchProvider(providers: [provider1, provider2])

        let results = try await aggregate.search(query: "test", limit: 10)

        XCTAssertEqual(results.count, 2)
        let feedURLs = Set(results.map { $0.feedURL.absoluteString })
        XCTAssertTrue(feedURLs.contains("https://a.com/feed"))
        XCTAssertTrue(feedURLs.contains("https://b.com/feed"))
    }

    // MARK: - Deduplication

    func testSearch_DeduplicatesByFeedURL_FirstProviderWins() async throws {
        let provider1 = MockSearchProvider(results: [
            makeResult(feedURL: "https://same.com/feed", title: "From Provider 1"),
        ])
        let provider2 = MockSearchProvider(results: [
            makeResult(feedURL: "https://same.com/feed", title: "From Provider 2"),
            makeResult(feedURL: "https://other.com/feed", title: "Unique"),
        ])
        let aggregate = AggregateSearchProvider(providers: [provider1, provider2])

        let results = try await aggregate.search(query: "test", limit: 10)

        XCTAssertEqual(results.count, 2, "Duplicate feed URL should be deduplicated")
        let sameFeedResult = results.first { $0.feedURL.absoluteString == "https://same.com/feed" }
        XCTAssertEqual(sameFeedResult?.title, "From Provider 1", "First provider's result should win on collision")
    }

    // MARK: - Error isolation

    func testSearch_ReturnsSuccessfulResults_WhenOneProviderFails() async throws {
        let failingProvider = MockSearchProvider(error: DirectorySearchError.networkError(URLError(.notConnectedToInternet)))
        let succeedingProvider = MockSearchProvider(results: [
            makeResult(feedURL: "https://success.com/feed", title: "Success"),
        ])
        let aggregate = AggregateSearchProvider(providers: [failingProvider, succeedingProvider])

        let results = try await aggregate.search(query: "test", limit: 10)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Success")
    }

    func testSearch_ThrowsFirstError_WhenAllProvidersFail() async {
        let error1 = DirectorySearchError.networkError(URLError(.timedOut))
        let error2 = DirectorySearchError.httpError(500)
        let provider1 = MockSearchProvider(error: error1)
        let provider2 = MockSearchProvider(error: error2)
        let aggregate = AggregateSearchProvider(providers: [provider1, provider2])

        do {
            _ = try await aggregate.search(query: "test", limit: 10)
            XCTFail("Expected an error when all providers fail")
        } catch {
            // Any DirectorySearchError is acceptable — the first error encountered is propagated.
            XCTAssertTrue(error is DirectorySearchError)
        }
    }

    // MARK: - Single provider passthrough

    func testSearch_WorksWithSingleProvider() async throws {
        let provider = MockSearchProvider(results: [
            makeResult(feedURL: "https://solo.com/feed", title: "Solo"),
        ])
        let aggregate = AggregateSearchProvider(providers: [provider])

        let results = try await aggregate.search(query: "solo", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Solo")
    }
}

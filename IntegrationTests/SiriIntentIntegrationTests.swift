//
//  SiriIntentIntegrationTests.swift
//  IntegrationTests
//
//  Created for Issue 02.1.8.1: CarPlay Siri Data Wiring
//

import XCTest
import Intents
@testable import SharedUtilities

/// Integration tests verifying that Siri intent handlers can load and search
/// podcast snapshots from the shared app group.
@available(iOS 14.0, *)
final class SiriIntentIntegrationTests: XCTestCase {
    
    private var testSuite: UserDefaults!
    private var testSuiteName: String!
    private var testPodcasts: [SiriPodcastSnapshot]!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create isolated test suite
        testSuiteName = "test.siri.intent.\(UUID().uuidString)"
        testSuite = try XCTUnwrap(UserDefaults(suiteName: testSuiteName))
        
        // Prepare test data
        let episode1 = SiriEpisodeSnapshot(
            id: "ep-swift-1",
            title: "Swift Concurrency Deep Dive",
            duration: 1800,
            playbackPosition: 0,
            isPlayed: false,
            publishedAt: ISO8601DateFormatter().date(from: "2024-01-15T10:00:00Z")
        )
        
        let episode2 = SiriEpisodeSnapshot(
            id: "ep-swift-2",
            title: "Latest SwiftUI Patterns",
            duration: 2100,
            playbackPosition: 300,
            isPlayed: false,
            publishedAt: ISO8601DateFormatter().date(from: "2024-05-20T10:00:00Z")
        )
        
        let episode3 = SiriEpisodeSnapshot(
            id: "ep-mobile-1",
            title: "Mobile Development Best Practices",
            duration: 1900,
            playbackPosition: 0,
            isPlayed: true,
            publishedAt: ISO8601DateFormatter().date(from: "2024-03-10T10:00:00Z")
        )
        
        testPodcasts = [
            SiriPodcastSnapshot(id: "pod-swift", title: "Swift Talk", episodes: [episode1, episode2]),
            SiriPodcastSnapshot(id: "pod-mobile", title: "Mobile Musings", episodes: [episode3])
        ]
        
        // Save to test suite
        try SiriMediaLibrary.save(testPodcasts, to: testSuite)
    }
    
    override func tearDownWithError() throws {
        // Clean up test suite
        if let suiteName = testSuiteName {
            testSuite?.removePersistentDomain(forName: suiteName)
        }
        testSuite = nil
        testSuiteName = nil
        testPodcasts = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Snapshot Persistence Tests
    
    func testSnapshotPersistenceAndDecoding() throws {
        // Given: Snapshots are saved to the test suite (done in setUp)
        
        // When: Loading snapshots from the suite
        let loaded = try SiriMediaLibrary.load(from: testSuite)
        
        // Then: All podcasts and episodes are correctly restored
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.id, "pod-swift")
        XCTAssertEqual(loaded.first?.episodes.count, 2)
        XCTAssertEqual(loaded.last?.id, "pod-mobile")
        XCTAssertEqual(loaded.last?.episodes.count, 1)
    }
    
    func testSnapshotPreservesEpisodeMetadata() throws {
        // Given: Episodes with various metadata
        let loaded = try SiriMediaLibrary.load(from: testSuite)
        
        // When: Examining episode metadata
        let swiftPodcast = try XCTUnwrap(loaded.first(where: { $0.id == "pod-swift" }))
        let latestEpisode = try XCTUnwrap(swiftPodcast.episodes.first(where: { $0.id == "ep-swift-2" }))
        
        // Then: Metadata is preserved
        XCTAssertEqual(latestEpisode.title, "Latest SwiftUI Patterns")
        XCTAssertEqual(latestEpisode.duration, 2100)
        XCTAssertEqual(latestEpisode.playbackPosition, 300)
        XCTAssertEqual(latestEpisode.isPlayed, false)
        XCTAssertNotNil(latestEpisode.publishedAt)
    }
    
    // MARK: - Fuzzy Search Tests
    
    func testFuzzySearchRanksByRelevance() throws {
        // Given: A resolver with test podcasts
        let resolver = SiriMediaResolver(podcasts: testPodcasts)
        
        // When: Searching for "swift"
        let matches = resolver.searchEpisodes(query: "swift", temporalReference: nil)
        
        // Then: Results are ranked by relevance (exact title match scores higher)
        XCTAssertEqual(matches.count, 2)
        XCTAssertTrue(matches.first!.score >= matches.last!.score)
        
        // Episode with "SwiftUI" should rank high
        let topMatch = try XCTUnwrap(matches.first)
        XCTAssertTrue(topMatch.episode.title.contains("Swift"))
    }
    
    func testFuzzySearchHandlesPartialMatches() throws {
        // Given: A resolver with test podcasts
        let resolver = SiriMediaResolver(podcasts: testPodcasts)
        
        // When: Searching with partial query
        let matches = resolver.searchEpisodes(query: "concurr", temporalReference: nil)
        
        // Then: Partial matches are found
        XCTAssertGreaterThan(matches.count, 0)
        XCTAssertTrue(matches.first!.episode.title.localizedCaseInsensitiveContains("concurrency"))
    }
    
    func testFuzzySearchReturnsEmptyForNoMatches() throws {
        // Given: A resolver with test podcasts
        let resolver = SiriMediaResolver(podcasts: testPodcasts)
        
        // When: Searching for non-existent content
        let matches = resolver.searchEpisodes(query: "kotlin programming language", temporalReference: nil)
        
        // Then: No matches are returned
        XCTAssertEqual(matches.count, 0)
    }
    
    // MARK: - Temporal Reference Tests
    
    func testTemporalReferenceLatestReturnsNewestEpisode() throws {
        // Given: A resolver with episodes from different dates
        let resolver = SiriMediaResolver(podcasts: testPodcasts)
        
        // When: Searching with "latest" temporal reference
        let matches = resolver.searchEpisodes(query: "swift", temporalReference: .latest)
        
        // Then: Only the newest matching episode is returned
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.episode.id, "ep-swift-2") // May 2024 episode
    }
    
    func testTemporalReferenceOldestReturnsOldestEpisode() throws {
        // Given: A resolver with episodes from different dates
        let resolver = SiriMediaResolver(podcasts: testPodcasts)
        
        // When: Searching with "oldest" temporal reference
        let matches = resolver.searchEpisodes(query: "swift", temporalReference: .oldest)
        
        // Then: Only the oldest matching episode is returned
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.episode.id, "ep-swift-1") // January 2024 episode
    }
    
    func testParseTemporalReferenceFromQuery() throws {
        // Test "latest" detection
        XCTAssertEqual(SiriMediaSearch.parseTemporalReference("play the latest swift episode"), .latest)
        XCTAssertEqual(SiriMediaSearch.parseTemporalReference("newest episode"), .latest)
        XCTAssertEqual(SiriMediaSearch.parseTemporalReference("play recent swift"), .latest)
        
        // Test "oldest" detection
        XCTAssertEqual(SiriMediaSearch.parseTemporalReference("play the first episode"), .oldest)
        XCTAssertEqual(SiriMediaSearch.parseTemporalReference("oldest swift episode"), .oldest)
        
        // Test no temporal reference
        XCTAssertNil(SiriMediaSearch.parseTemporalReference("play swift episode"))
    }
    
    // MARK: - Podcast-Level Search Tests
    
    func testSearchPodcastsByTitle() throws {
        // Given: A resolver with test podcasts
        let resolver = SiriMediaResolver(podcasts: testPodcasts)
        
        // When: Searching for podcast by title
        let matches = resolver.searchPodcasts(query: "swift talk")
        
        // Then: Correct podcast is found
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.podcast.id, "pod-swift")
        XCTAssertEqual(matches.first?.podcast.title, "Swift Talk")
    }
    
    func testSearchPodcastsLimitsResults() throws {
        // Given: A resolver with limited result count
        let manyPodcasts = (1...20).map { i in
            SiriPodcastSnapshot(
                id: "pod-\(i)",
                title: "Podcast Number \(i)",
                episodes: []
            )
        }
        let resolver = SiriMediaResolver(podcasts: manyPodcasts, resultLimit: 5)
        
        // When: Searching for a common term
        let matches = resolver.searchPodcasts(query: "podcast")
        
        // Then: Results are limited to 5
        XCTAssertEqual(matches.count, 5)
    }
    
    // MARK: - Resolver Loading Tests
    
    func testLoadResolverFromPrimarySuite() throws {
        // Given: Snapshots saved in a primary suite
        let primarySuite = "test.primary.\(UUID().uuidString)"
        defer {
            UserDefaults(suiteName: primarySuite)?.removePersistentDomain(forName: primarySuite)
        }
        
        let primaryDefaults = try XCTUnwrap(UserDefaults(suiteName: primarySuite))
        try SiriMediaLibrary.save(testPodcasts, to: primaryDefaults)
        
        // When: Loading resolver with primary suite
        let resolver = try XCTUnwrap(
            SiriMediaResolver.loadResolver(primarySuite: primarySuite)
        )
        
        // Then: Resolver successfully loads podcasts
        let matches = resolver.searchPodcasts(query: "swift")
        XCTAssertGreaterThan(matches.count, 0)
    }
    
    func testLoadResolverFallsBackToDevSuite() throws {
        // Given: Empty primary suite, but populated dev suite
        let primarySuite = "test.primary.empty.\(UUID().uuidString)"
        let devSuite = "test.dev.\(UUID().uuidString)"
        
        defer {
            UserDefaults(suiteName: primarySuite)?.removePersistentDomain(forName: primarySuite)
            UserDefaults(suiteName: devSuite)?.removePersistentDomain(forName: devSuite)
        }
        
        let devDefaults = try XCTUnwrap(UserDefaults(suiteName: devSuite))
        try SiriMediaLibrary.save(testPodcasts, to: devDefaults)
        
        // When: Loading resolver with fallback
        let resolver = try XCTUnwrap(
            SiriMediaResolver.loadResolver(primarySuite: primarySuite, devSuite: devSuite)
        )
        
        // Then: Resolver loads from dev suite
        let matches = resolver.searchPodcasts(query: "mobile")
        XCTAssertGreaterThan(matches.count, 0)
    }
    
    func testLoadResolverReturnsNilWhenNoDataAvailable() throws {
        // Given: Empty suites
        let primarySuite = "test.empty.primary.\(UUID().uuidString)"
        let devSuite = "test.empty.dev.\(UUID().uuidString)"
        
        defer {
            UserDefaults(suiteName: primarySuite)?.removePersistentDomain(forName: primarySuite)
            UserDefaults(suiteName: devSuite)?.removePersistentDomain(forName: devSuite)
        }
        
        // When: Loading resolver with no data
        let resolver = SiriMediaResolver.loadResolver(primarySuite: primarySuite, devSuite: devSuite)
        
        // Then: Resolver is nil
        XCTAssertNil(resolver)
    }
    
    // MARK: - Identifier Hand-off Tests
    
    func testResolvedIdentifiersMatchOriginalEpisodeIds() throws {
        // Given: A resolver with known episodes
        let resolver = SiriMediaResolver(podcasts: testPodcasts)
        
        // When: Searching for an episode
        let matches = resolver.searchEpisodes(query: "concurrency", temporalReference: nil)
        
        // Then: The resolved identifier matches the original episode ID
        let match = try XCTUnwrap(matches.first)
        XCTAssertEqual(match.episode.id, "ep-swift-1")
        
        // The ID can be used to trigger playback in the main app
        XCTAssertFalse(match.episode.id.isEmpty)
    }
    
    func testPodcastContextPreservedInEpisodeMatches() throws {
        // Given: A resolver with multiple podcasts
        let resolver = SiriMediaResolver(podcasts: testPodcasts)
        
        // When: Searching for episodes across podcasts
        let matches = resolver.searchEpisodes(query: "mobile", temporalReference: nil)
        
        // Then: Each match includes its parent podcast context
        let match = try XCTUnwrap(matches.first)
        XCTAssertEqual(match.podcast.id, "pod-mobile")
        XCTAssertEqual(match.podcast.title, "Mobile Musings")
        XCTAssertEqual(match.episode.id, "ep-mobile-1")
    }
}

import XCTest
@testable import SharedUtilities

@available(iOS 14.0, *)
final class SiriMediaResolverTests: XCTestCase {
    private func makeSnapshots() -> [SiriPodcastSnapshot] {
        let formatter = ISO8601DateFormatter()
        let episodesA = [
            SiriEpisodeSnapshot(
                id: "episode-a-1",
                title: "Swift Concurrency Deep Dive",
                duration: 1800,
                playbackPosition: 0,
                isPlayed: false,
                publishedAt: formatter.date(from: "2024-01-10T10:00:00Z")
            ),
            SiriEpisodeSnapshot(
                id: "episode-a-2",
                title: "Latest SwiftUI Techniques",
                duration: 2000,
                playbackPosition: 0,
                isPlayed: false,
                publishedAt: formatter.date(from: "2024-05-12T10:00:00Z")
            )
        ]

        let episodesB = [
            SiriEpisodeSnapshot(
                id: "episode-b-1",
                title: "Kotlin vs Swift",
                duration: 2100,
                playbackPosition: 0,
                isPlayed: false,
                publishedAt: formatter.date(from: "2023-11-01T10:00:00Z")
            )
        ]

        return [
            SiriPodcastSnapshot(id: "podcast-a", title: "Swift Talk", episodes: episodesA),
            SiriPodcastSnapshot(id: "podcast-b", title: "Mobile Musings", episodes: episodesB)
        ]
    }

    func testSearchEpisodesReturnsSortedMatches() throws {
        let resolver = SiriMediaResolver(podcasts: makeSnapshots())

        let matches = resolver.searchEpisodes(query: "swift", temporalReference: nil)
        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches.first?.episode.id, "episode-a-2")
    }

    func testTemporalReferenceLatestReturnsNewestEpisode() throws {
        let resolver = SiriMediaResolver(podcasts: makeSnapshots())
        let matches = resolver.searchEpisodes(query: "swift", temporalReference: .latest)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.episode.id, "episode-a-2")
    }

    func testLoadResolverFallsBackToDevSuite() throws {
        let suiteName = "test-resolver-\(UUID().uuidString)"
        let devSuite = "test-resolver-dev-\(UUID().uuidString)"

        defer {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
            UserDefaults(suiteName: devSuite)?.removePersistentDomain(forName: devSuite)
        }

        let devDefaults = try XCTUnwrap(UserDefaults(suiteName: devSuite))
        let snapshots = makeSnapshots()
        try SiriMediaLibrary.save(snapshots, to: devDefaults)

        let resolver = SiriMediaResolver.loadResolver(primarySuite: suiteName, devSuite: devSuite)
        let matches = resolver?.searchPodcasts(query: "swift") ?? []
        XCTAssertEqual(matches.first?.podcast.id, "podcast-a")
    }
}

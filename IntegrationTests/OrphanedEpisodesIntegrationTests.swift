import XCTest
import SwiftData
@testable import CoreModels
@testable import Persistence
@testable import TestSupport

@available(iOS 17, macOS 14, watchOS 10, *)
final class OrphanedEpisodesIntegrationTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: SwiftDataPodcastRepository!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([PodcastEntity.self, EpisodeEntity.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        repository = SwiftDataPodcastRepository(modelContainer: container)
    }

    override func tearDown() async throws {
        repository = nil
        container = nil
        try await super.tearDown()
    }

    func testOrphanedEpisodeWorkflow() {
        // Seed with one episode that will become orphaned
        let podcast = MockPodcast.createSample(
            id: "pod-orphan-flow",
            title: "Orphan Flow",
            episodes: [
                MockEpisode.create(id: "ep-orphan", playbackPosition: 45)
            ]
        )
        repository.add(podcast)

        // Feed refresh removes episode but preserves user state -> mark orphaned
        let refreshed = MockPodcast.createSample(id: podcast.id, title: podcast.title, episodes: [])
        repository.update(refreshed)

        var orphans = repository.fetchOrphanedEpisodes()
        XCTAssertEqual(orphans.count, 1)
        XCTAssertEqual(orphans.first?.id, "ep-orphan")
        XCTAssertTrue(orphans.first?.isOrphaned ?? false)

        // Bulk delete
        let removed = repository.deleteAllOrphanedEpisodes()
        XCTAssertEqual(removed, 1)
        orphans = repository.fetchOrphanedEpisodes()
        XCTAssertTrue(orphans.isEmpty)
    }
}

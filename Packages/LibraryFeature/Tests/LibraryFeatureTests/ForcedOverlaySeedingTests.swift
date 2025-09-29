import XCTest
@testable import LibraryFeature
import CoreModels

@MainActor
final class ForcedOverlaySeedingTests: XCTestCase {
  override func tearDown() {
    unsetenv("UITEST_FORCE_BATCH_OVERLAY")
    super.tearDown()
  }

  func testEnsuresForcedOverlaySeedsBatchOperation() async {
    setenv("UITEST_FORCE_BATCH_OVERLAY", "1", 1)

    let episodes = (1...3).map { index in
      Episode(
        id: "episode-\(index)",
        title: "Episode #\(index)",
        podcastID: "podcast-id",
        podcastTitle: "Test Podcast",
        duration: 1800,
        description: "Episode description \(index)",
        audioURL: URL(string: "https://example.com/episode\(index).mp3")
      )
    }
    let podcast = Podcast(
      id: "podcast-id",
      title: "Test Podcast",
      author: "Tester",
      feedURL: URL(string: "https://example.com/feed.rss")!,
      episodes: episodes
    )

    let viewModel = EpisodeListViewModel(podcast: podcast)

    await viewModel.ensureUITestBatchOverlayIfNeeded(after: 0.0)

    XCTAssertEqual(viewModel.activeBatchOperations.count, 1)
    guard let operation = viewModel.activeBatchOperations.first else {
      XCTFail("Expected forced overlay operation")
      return
    }

    XCTAssertEqual(operation.operationType, .markAsPlayed)
    XCTAssertFalse(operation.operations.isEmpty)
  }
}

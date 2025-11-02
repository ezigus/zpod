import XCTest
@testable import SharedUtilities

@available(iOS 14.0, *)
final class SiriMediaLibraryTests: XCTestCase {

  func testSaveAndLoadSnapshots() throws {
    let suiteName = "test.sirimedia." + UUID().uuidString
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create suite defaults")
      return
    }

    let episodes = [
      SiriEpisodeSnapshot(id: "ep-1", title: "Episode One", duration: 1800, playbackPosition: 0, isPlayed: false, publishedAt: Date()),
      SiriEpisodeSnapshot(id: "ep-2", title: "Episode Two", duration: 1200, playbackPosition: 600, isPlayed: true, publishedAt: Date().addingTimeInterval(-86400))
    ]

    let podcasts = [
      SiriPodcastSnapshot(id: "pod-1", title: "Swift Talk", episodes: episodes)
    ]

    try SiriMediaLibrary.save(podcasts, to: defaults)
    let loaded = try SiriMediaLibrary.load(from: defaults)

    XCTAssertEqual(loaded, podcasts)
  }

  func testLoadFromSharedContainerGracefullyHandlesMissingSuite() {
    let snapshots = SiriMediaLibrary.loadFromSharedContainer(suiteName: "invalid.suite")
    XCTAssertTrue(snapshots.isEmpty)
  }
}

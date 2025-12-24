import CoreModels
import PlaybackEngine
import XCTest
@testable import LibraryFeature

final class NowPlayingInfoBuilderTests: XCTestCase {
  private let builder = NowPlayingInfoBuilder()

  func testPlayingStateBuildsSnapshot() {
    let episode = Episode(
      id: "episode-1",
      title: "Test Episode",
      podcastID: "podcast-1",
      podcastTitle: "Test Podcast",
      playbackPosition: 0,
      isPlayed: false,
      duration: 300,
      artworkURL: URL(string: "https://example.com/artwork.png")
    )

    let snapshot = builder.makeSnapshot(from: .playing(episode, position: 45, duration: 300))

    XCTAssertEqual(snapshot?.title, "Test Episode")
    XCTAssertEqual(snapshot?.podcastTitle, "Test Podcast")
    XCTAssertEqual(snapshot?.duration, 300)
    XCTAssertEqual(snapshot?.elapsed, 45)
    XCTAssertEqual(snapshot?.playbackRate, 1.0)
    XCTAssertEqual(snapshot?.artworkURL, episode.artworkURL)
  }

  func testPausedStateBuildsSnapshotWithZeroRate() {
    let episode = Episode(
      id: "episode-2",
      title: "Paused Episode",
      podcastTitle: "Paused Podcast",
      playbackPosition: 0,
      isPlayed: false,
      duration: 200
    )

    let snapshot = builder.makeSnapshot(from: .paused(episode, position: 120, duration: 200))

    XCTAssertEqual(snapshot?.playbackRate, 0.0)
    XCTAssertEqual(snapshot?.elapsed, 120)
  }

  func testFinishedStateBuildsSnapshotAtEnd() {
    let episode = Episode(
      id: "episode-3",
      title: "Finished Episode",
      podcastTitle: "Finished Podcast",
      playbackPosition: 0,
      isPlayed: true,
      duration: 180
    )

    let snapshot = builder.makeSnapshot(from: .finished(episode, duration: 180))

    XCTAssertEqual(snapshot?.playbackRate, 0.0)
    XCTAssertEqual(snapshot?.elapsed, 180)
    XCTAssertEqual(snapshot?.duration, 180)
  }

  func testIdleStateClearsSnapshot() {
    let episode = Episode(id: "episode-4", title: "Idle", description: "")

    let snapshot = builder.makeSnapshot(from: .idle(episode))

    XCTAssertNil(snapshot)
  }
}

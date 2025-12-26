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

  func testFailedStateBuildsSnapshotWithZeroRate() {
    let episode = Episode(
      id: "episode-5",
      title: "Failed Episode",
      podcastTitle: "Failed Podcast",
      playbackPosition: 0,
      isPlayed: false,
      duration: 180
    )

    let snapshot = builder.makeSnapshot(from: .failed(episode, position: 90, duration: 180, error: .streamFailed))

    XCTAssertEqual(snapshot?.title, "Failed Episode")
    XCTAssertEqual(snapshot?.podcastTitle, "Failed Podcast")
    XCTAssertEqual(snapshot?.duration, 180)
    XCTAssertEqual(snapshot?.elapsed, 90)
    XCTAssertEqual(snapshot?.playbackRate, 0.0)
  }

  // MARK: - Edge Cases

  func testBuilderHandlesZeroDuration() {
    let episode = Episode(
      id: "episode-zero",
      title: "Zero Duration",
      podcastTitle: "Test",
      playbackPosition: 0,
      isPlayed: false,
      duration: 0
    )

    let snapshot = builder.makeSnapshot(from: .playing(episode, position: 0, duration: 0))

    XCTAssertEqual(snapshot?.duration, 0)
    XCTAssertEqual(snapshot?.elapsed, 0)
  }

  func testBuilderHandlesNegativeDuration() {
    let episode = Episode(
      id: "episode-neg",
      title: "Negative Duration",
      podcastTitle: "Test",
      playbackPosition: 0,
      isPlayed: false,
      duration: -100
    )

    let snapshot = builder.makeSnapshot(from: .playing(episode, position: 50, duration: -100))

    XCTAssertEqual(snapshot?.duration, 0, "Negative duration should be normalized to 0")
    // When duration is unknown (normalized to 0), keep elapsed as-is so progress doesn't reset.
    XCTAssertEqual(snapshot?.elapsed, 50, "Position stays as-is when duration becomes 0")
  }

  func testBuilderClampsPositionToValidRange() {
    let episode = Episode(
      id: "episode-clamp",
      title: "Clamp Test",
      podcastTitle: "Test",
      playbackPosition: 0,
      isPlayed: false,
      duration: 100
    )

    let snapshot = builder.makeSnapshot(from: .playing(episode, position: 150, duration: 100))

    XCTAssertEqual(snapshot?.elapsed, 100, "Position beyond duration should be clamped to duration")
  }

  func testBuilderHandlesNegativePosition() {
    let episode = Episode(
      id: "episode-neg-pos",
      title: "Negative Position",
      podcastTitle: "Test",
      playbackPosition: 0,
      isPlayed: false,
      duration: 100
    )

    let snapshot = builder.makeSnapshot(from: .playing(episode, position: -50, duration: 100))

    XCTAssertEqual(snapshot?.elapsed, 0, "Negative position should be normalized to 0")
  }

  func testBuilderHandlesLargeValues() {
    let episode = Episode(
      id: "episode-large",
      title: "Large Duration",
      podcastTitle: "Test",
      playbackPosition: 0,
      isPlayed: false,
      duration: 3600 * 24  // 24 hours
    )

    let snapshot = builder.makeSnapshot(from: .playing(episode, position: 43200, duration: 86400))

    XCTAssertEqual(snapshot?.duration, 86400)
    XCTAssertEqual(snapshot?.elapsed, 43200)
    XCTAssertEqual(snapshot?.playbackRate, 1.0)
  }
}

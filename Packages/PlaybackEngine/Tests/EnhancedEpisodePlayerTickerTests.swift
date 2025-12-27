import XCTest
#if canImport(Combine)
@preconcurrency import CombineSupport
import Combine
#endif
@testable import PlaybackEngine
import CoreModels
import SharedUtilities

/// Tests for position ticking functionality in EnhancedEpisodePlayer.
///
/// **Spec Reference**: `zpod/spec/playback.md` - Core Playback Behavior
/// - Timeline Advancement During Playback
/// - Pausing and Resuming Playback
@MainActor
final class EnhancedEpisodePlayerTickerTests: XCTestCase {
  private var player: EnhancedEpisodePlayer!
  private var cancellables: Set<AnyCancellable>!

  override func setUp() async throws {
    try await super.setUp()
    player = EnhancedEpisodePlayer()
    cancellables = []
  }

  override func tearDown() async throws {
    cancellables = nil
    player = nil
    try await super.tearDown()
  }

  // MARK: - Position Advancement Tests

  /// **Scenario**: Timeline Advancement During Playback
  /// **Given** an episode is playing
  /// **When** time passes
  /// **Then** playback position advances and state updates emit
  func testPositionAdvancesDuringPlayback() async throws {
    // Given: A player with an episode
    let episode = Episode(id: "test-ep-1", title: "Test Episode", duration: 60)
    var receivedStates: [EpisodePlaybackState] = []

    #if canImport(Combine)
      player.statePublisher
        .sink { state in
          receivedStates.append(state)
        }
        .store(in: &cancellables)
    #endif

    // When: Play and wait ~1.1 seconds (should get ~2 ticks at 0.5s interval)
    player.play(episode: episode, duration: 60)
    try await Task.sleep(for: .seconds(1.1))

    // Then: Position should have advanced
    #if canImport(Combine)
      // Should have received: idle (initial), playing (play()), playing (tick 1), playing (tick 2)
      XCTAssertGreaterThanOrEqual(receivedStates.count, 3, "Should have received multiple state updates")

      // Verify last state shows advanced position
      if case .playing(_, let position, _) = receivedStates.last {
        XCTAssertGreaterThan(position, 0.5, "Position should have advanced at least one tick (0.5s)")
        XCTAssertLessThan(position, 2.0, "Position shouldn't advance too far (sanity check)")
      } else {
        XCTFail("Last state should be .playing")
      }
    #endif

    // Verify current position advanced
    XCTAssertGreaterThan(player.currentPosition, 0.5)
  }

  /// **Scenario**: Pausing Playback
  /// **Given** an episode is playing
  /// **When** the user taps pause
  /// **Then** playback position stops advancing
  func testPositionStopsOnPause() async throws {
    // Given: A playing episode
    let episode = Episode(id: "test-ep-2", title: "Pause Test", duration: 60)
    player.play(episode: episode, duration: 60)
    try await Task.sleep(for: .seconds(0.6))

    // When: Pause
    player.pause()
    let positionAtPause = player.currentPosition
    try await Task.sleep(for: .seconds(0.6))

    // Then: Position should not have changed
    XCTAssertEqual(
      player.currentPosition,
      positionAtPause,
      accuracy: 0.01,
      "Position should not advance after pause"
    )
  }

  /// **Scenario**: Resuming Playback
  /// **Given** an episode is paused
  /// **When** the user taps play
  /// **Then** playback position resumes advancing
  func testPositionResumesAfterPause() async throws {
    // Given: A paused episode
    let episode = Episode(id: "test-ep-3", title: "Resume Test", duration: 60)
    player.play(episode: episode, duration: 60)
    try await Task.sleep(for: .seconds(0.6))
    player.pause()
    // When: Resume play
    let resumeEpisode = player.currentEpisode ?? episode
    let resumeBaseline = Double(resumeEpisode.playbackPosition)
    player.play(episode: resumeEpisode, duration: 60)
    try await Task.sleep(for: .seconds(0.6))

    // Then: Position should have advanced beyond pause point
    XCTAssertGreaterThan(
      player.currentPosition,
      resumeBaseline,
      "Position should resume advancing after play"
    )
  }

  /// **Scenario**: Episode Reaches End
  /// **Given** an episode is playing near the end
  /// **When** position reaches duration
  /// **Then** playback finishes and ticker stops
  func testFinishStateWhenPositionReachesDuration() async throws {
    // Given: An episode with short duration
    let episode = Episode(id: "test-ep-4", title: "Finish Test", duration: 1.0)
    var finishedEmitted = false

    #if canImport(Combine)
      player.statePublisher
        .sink { state in
          if case .finished = state {
            finishedEmitted = true
          }
        }
        .store(in: &cancellables)
    #endif

    // When: Play episode with 1 second duration
    player.play(episode: episode, duration: 1.0)
    try await Task.sleep(for: .seconds(1.5))

    // Then: Should have emitted finished state
    #if canImport(Combine)
      XCTAssertTrue(finishedEmitted, "Should emit .finished when position reaches duration")
    #endif

    // Verify playback stopped
    XCTAssertFalse(player.isPlaying, "Should not be playing after finish")

    // Verify position at end
    XCTAssertEqual(
      player.currentPosition,
      1.0,
      accuracy: 0.01,
      "Position should be at duration"
    )
  }

  // MARK: - Ticker Lifecycle Tests

  /// **Scenario**: Ticker Cleanup on Failure
  /// **Given** an episode is playing
  /// **When** playback fails
  /// **Then** ticker stops and position doesn't advance
  func testTickerStopsOnFailure() async throws {
    // Given: A playing episode
    let episode = Episode(id: "test-ep-5", title: "Failure Test", duration: 60)
    player.play(episode: episode, duration: 60)
    try await Task.sleep(for: .seconds(0.6))

    // When: Playback fails
    player.failPlayback(error: .streamFailed)
    let positionAtFailure = player.currentPosition
    try await Task.sleep(for: .seconds(0.6))

    // Then: Position should not advance
    XCTAssertEqual(
      player.currentPosition,
      positionAtFailure,
      accuracy: 0.01,
      "Position should not advance after failure"
    )
  }

  /// **Scenario**: State Updates During Playback
  /// **Given** an episode is playing
  /// **When** multiple ticks occur
  /// **Then** state publisher emits updated states with advancing position
  func testStatePublisherEmitsUpdates() async throws {
    // Given: An episode
    let episode = Episode(id: "test-ep-6", title: "State Updates Test", duration: 60)
    var positions: [TimeInterval] = []

    #if canImport(Combine)
      player.statePublisher
        .sink { state in
          if case .playing(_, let position, _) = state {
            positions.append(position)
          }
        }
        .store(in: &cancellables)
    #endif

    // When: Play and wait for multiple ticks
    player.play(episode: episode, duration: 60)
    try await Task.sleep(for: .seconds(1.6))

    // Then: Should have received multiple position updates
    #if canImport(Combine)
      XCTAssertGreaterThanOrEqual(positions.count, 3, "Should receive multiple state updates")

      // Verify positions are monotonically increasing
      for i in 1..<positions.count {
        XCTAssertGreaterThan(
          positions[i],
          positions[i - 1],
          "Positions should increase over time"
        )
      }
    #endif
  }

  /// **Scenario**: Playback Speed Affects Timeline
  /// **Given** playback speed is increased
  /// **When** time passes during playback
  /// **Then** position advances faster than normal speed
  func testPlaybackSpeedScalesTickProgress() async throws {
    // Given: An episode is playing
    let episode = Episode(id: "test-ep-8", title: "Speed Test", duration: 60)
    player.play(episode: episode, duration: 60)

    // When: Increase playback speed and wait for ticks
    player.setPlaybackSpeed(2.0)
    try await Task.sleep(for: .seconds(1.1))

    // Then: Position should advance faster than 1x (>= 1.5s over ~1.1s)
    XCTAssertGreaterThan(
      player.currentPosition,
      1.5,
      "Position should advance faster when playback speed is increased"
    )
  }

  /// **Scenario**: Chapter Updates During Playback
  /// **Given** an episode with chapters is playing
  /// **When** position crosses chapter boundary
  /// **Then** current chapter index updates
  func testChapterIndexUpdatesWithTicks() async throws {
    // Given: An episode with custom chapters
    let episode = Episode(id: "test-ep-7", title: "Chapter Test", duration: 60)
    let chapters = [
      Chapter(id: "ch1", title: "Intro", startTime: 0, endTime: 10),
      Chapter(id: "ch2", title: "Main", startTime: 10, endTime: 50),
      Chapter(id: "ch3", title: "Outro", startTime: 50, endTime: 60),
    ]

    let chapterResolver: (Episode, TimeInterval) -> [Chapter] = { _, _ in chapters }
    let playerWithChapters = EnhancedEpisodePlayer(chapterResolver: chapterResolver)

    // When: Play and let position advance past chapter boundary
    playerWithChapters.play(episode: episode, duration: 60)
    // Seek to just before chapter 2
    playerWithChapters.seek(to: 9.5)
    try await Task.sleep(for: .seconds(0.7))  // Should tick into chapter 2

    // Then: Position should be in chapter 2 range
    XCTAssertGreaterThanOrEqual(playerWithChapters.currentPosition, 10.0)
    XCTAssertLessThan(playerWithChapters.currentPosition, 50.0)
  }
}

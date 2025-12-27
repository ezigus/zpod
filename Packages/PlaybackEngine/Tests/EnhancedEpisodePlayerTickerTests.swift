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
    var receivedStates: [EpisodePlaybackState] = []

    #if canImport(Combine)
      player.statePublisher
        .sink { receivedStates.append($0) }
        .store(in: &cancellables)
    #endif

    player.play(episode: episode, duration: 60)
    let stateCountBeforeSpeed = receivedStates.count

    // When: Increase playback speed
    player.setPlaybackSpeed(2.0)

    // Then: State should be emitted immediately
    #if canImport(Combine)
      XCTAssertEqual(
        receivedStates.count,
        stateCountBeforeSpeed + 1,
        "Speed change should emit state"
      )
    #endif

    // And: Position should advance faster than 1x (>= 1.5s over ~1.1s)
    try await Task.sleep(for: .seconds(1.1))
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

  // MARK: - State Injection Tests

  /// **Scenario**: Restoring Playing State
  /// **Given** player is idle
  /// **When** .playing state is injected (e.g., app relaunch)
  /// **Then** ticker starts and position advances
  func testInjectPlayingStateStartsTicker() async throws {
    // Given: Player in idle state
    let episode = Episode(id: "test-inject-1", title: "Inject Test", duration: 60)

    // When: Inject .playing state
    player.injectPlaybackState(.playing(episode, position: 10, duration: 60))
    try await Task.sleep(for: .seconds(0.6))

    // Then: Position should advance beyond injected position
    XCTAssertGreaterThan(
      player.currentPosition,
      10.0,
      "Position should advance after injecting .playing state"
    )
  }

  /// **Scenario**: Stopping Ticker on State Injection
  /// **Given** player is actively playing
  /// **When** .paused state is injected
  /// **Then** ticker stops and position freezes
  func testInjectPausedStateStopsTicker() async throws {
    // Given: Player actively playing
    let episode = Episode(id: "test-inject-2", title: "Inject Pause Test", duration: 60)
    player.play(episode: episode, duration: 60)
    try await Task.sleep(for: .seconds(0.6))

    // When: Inject .paused state
    player.injectPlaybackState(.paused(episode, position: 5, duration: 60))
    let pausedPosition = player.currentPosition
    try await Task.sleep(for: .seconds(0.6))

    // Then: Position should not advance
    XCTAssertEqual(
      player.currentPosition,
      pausedPosition,
      accuracy: 0.01,
      "Position should not advance after injecting .paused state"
    )
  }

  // MARK: - Seek and Speed Edge Cases

  /// **Scenario**: Seek During Active Playback
  /// **Given** episode is playing
  /// **When** user seeks to new position
  /// **Then** ticker restarts and position continues advancing
  func testSeekDuringPlaybackContinuesTicking() async throws {
    // Given: Episode playing
    let episode = Episode(id: "test-seek-1", title: "Seek Test", duration: 60)
    player.play(episode: episode, duration: 60)
    try await Task.sleep(for: .seconds(0.6))

    // When: Seek to new position
    player.seek(to: 30)
    let seekPosition = player.currentPosition
    try await Task.sleep(for: .seconds(0.6))

    // Then: Position should advance from seek position
    XCTAssertGreaterThan(
      player.currentPosition,
      seekPosition,
      "Position should continue advancing after seek during playback"
    )
  }

  /// **Scenario**: High Speed Near Episode End
  /// **Given** episode playing at high speed near end
  /// **When** position approaches duration
  /// **Then** final state updates emitted before finish
  func testHighSpeedNearEndDoesntSkipStates() async throws {
    // Given: Episode with high speed playback near end
    let episode = Episode(id: "test-highspeed-1", title: "High Speed Test", duration: 60)
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

    player.play(episode: episode, duration: 60)
    player.seek(to: 58.0)
    player.setPlaybackSpeed(5.0)
    try await Task.sleep(for: .seconds(1.0))

    // Then: Should have emitted at least one state near 60s before finish
    #if canImport(Combine)
      XCTAssertTrue(
        positions.contains(where: { $0 >= 59.0 }),
        "Should emit state near end before finishing at high speed"
      )
    #endif
  }

  // MARK: - Spec-Driven Tests

  /// **Scenario**: Starting Episode Playback with Saved Position
  /// **Spec**: zpod/spec/playback.md line 55-60
  /// **Given** episode has saved playback position
  /// **When** user taps play
  /// **Then** playback starts at saved position and advances
  func testInitialPlaybackPositionRespectsSavedState() async throws {
    // Given: Episode with saved position
    let episode = Episode(id: "test-spec-1", title: "Saved Position Test", duration: 60)
      .withPlaybackPosition(25)

    // When: Play episode
    player.play(episode: episode, duration: 60)

    // Then: Position should start at saved position
    XCTAssertEqual(player.currentPosition, 25.0, accuracy: 0.1, "Should start at saved position")

    // And: Position should advance from there
    try await Task.sleep(for: .seconds(0.6))
    XCTAssertGreaterThan(player.currentPosition, 25.0, "Position should advance from saved position")
  }

  /// **Scenario**: Seeking to Position While Paused
  /// **Spec**: zpod/spec/playback.md line 82-86
  /// **Given** episode is paused
  /// **When** user seeks to new position
  /// **Then** position updates but ticker does not start
  func testSeekWhilePausedUpdatesPosition() async throws {
    // Given: Paused episode
    let episode = Episode(id: "test-spec-2", title: "Seek Paused Test", duration: 60)
    player.play(episode: episode, duration: 60)
    try await Task.sleep(for: .seconds(0.6))
    player.pause()

    // When: Seek to position
    player.seek(to: 40.0)

    // Then: Position updated but ticker not started
    XCTAssertEqual(player.currentPosition, 40.0, accuracy: 0.1, "Position should be updated")

    try await Task.sleep(for: .seconds(0.6))
    XCTAssertEqual(
      player.currentPosition,
      40.0,
      accuracy: 0.1,
      "Position should not advance while paused"
    )
  }

  // MARK: - Speed Clamping and Resume Tests (User Findings)

  /// **Scenario**: Speed Clamping to Minimum
  /// **Given** player instance
  /// **When** speed set below minimum (0.8)
  /// **Then** speed is clamped to minimum
  func testSpeedClampingToMinimum() async throws {
    // When: Set speed below minimum (0.8)
    player.setPlaybackSpeed(0.1)

    // Then: Speed should be clamped to minimum
    XCTAssertEqual(player.getCurrentPlaybackSpeed(), 0.8, accuracy: 0.01, "Speed should be clamped to minimum 0.8")
  }

  /// **Scenario**: Speed Clamping to Maximum
  /// **Given** player instance
  /// **When** speed set above maximum (5.0)
  /// **Then** speed is clamped to maximum
  func testSpeedClampingToMaximum() async throws {
    // When: Set speed above maximum (5.0)
    player.setPlaybackSpeed(10.0)

    // Then: Speed should be clamped to maximum
    XCTAssertEqual(player.getCurrentPlaybackSpeed(), 5.0, accuracy: 0.01, "Speed should be clamped to maximum 5.0")
  }

  /// **Scenario**: Resume Starts at Exact Persisted Position
  /// **Given** episode with saved playback position
  /// **When** play episode (resume)
  /// **Then** initial position exactly matches saved position (before any ticks)
  func testResumeStartsAtExactPersistedPosition() async throws {
    // Given: Episode with saved playback position
    let episode = Episode(id: "test-resume-1", title: "Resume Test", duration: 60)
      .withPlaybackPosition(42)  // Saved at 42 seconds

    // When: Play episode (resume)
    player.play(episode: episode, duration: 60)

    // Then: Initial position should EXACTLY match saved position (before any ticks)
    XCTAssertEqual(
      player.currentPosition,
      42.0,
      accuracy: 0.01,
      "Resume should start at exact persisted position"
    )

    // And: Position should advance after resume
    try await Task.sleep(for: .seconds(0.6))
    XCTAssertGreaterThan(
      player.currentPosition,
      42.0,
      "Position should advance after resume"
    )
  }

  // MARK: - Edge Case Tests

  /// **Scenario**: Zero Duration Episode Falls Back to Default
  /// **Given** episode with 0 duration
  /// **When** attempt to play
  /// **Then** fallback to default duration and ticker starts
  func testZeroDurationEpisodeFallsBackToDefault() async throws {
    // Given: Episode with 0 duration
    let episode = Episode(id: "test-edge-1", title: "Zero Duration Test", duration: 0)

    // When: Attempt to play
    player.play(episode: episode, duration: 0)

    // Then: Should use default duration (300s) and ticker starts
    XCTAssertEqual(player.currentPosition, 0, "Position should start at zero")
    try await Task.sleep(for: .seconds(0.6))
    // With fallback to default duration (300s), ticker starts normally
    XCTAssertGreaterThan(player.currentPosition, 0, "Position should advance with fallback duration")
  }

  /// **Scenario**: Rapid State Transitions
  /// **Given** episode
  /// **When** rapid play/pause/seek transitions
  /// **Then** should handle gracefully without crashes
  func testRapidStateTransitionsStable() async throws {
    // Given: Episode
    let episode = Episode(id: "test-edge-2", title: "Rapid Transition Test", duration: 60)

    // When: Rapid transitions
    player.play(episode: episode, duration: 60)
    try await Task.sleep(for: .seconds(0.1))
    player.pause()
    try await Task.sleep(for: .seconds(0.1))
    player.play(episode: episode, duration: 60)
    try await Task.sleep(for: .seconds(0.1))
    player.seek(to: 30)
    try await Task.sleep(for: .seconds(0.1))
    player.pause()

    // Then: Should handle gracefully without crashes
    XCTAssertFalse(player.isPlaying, "Should be paused after rapid transitions")
    XCTAssertEqual(player.currentPosition, 30.0, accuracy: 0.5, "Position should stabilize at seek target")
  }
}

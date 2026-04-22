#if os(iOS)
//
//  PlaybackCompletionTests.swift
//  LibraryFeatureTests
//
//  Spec-mapping tests for Issue 06.4.1 / Spec 06.4 Scenario 5:
//  Auto-Mark as Played at Completion Threshold.
//
//  Each test maps directly to a clause in the spec's Given/When/Then for Scenario 5.
//

import XCTest
import CombineSupport
@testable import LibraryFeature
import CoreModels
import PlaybackEngine

/// Spec 06.4 Scenario 5: Auto-Mark as Played at Completion Threshold
///
/// Given I navigate to Settings > Playback > Completion Threshold
/// When I set the threshold (choices: 90%, 95%, 99%)
/// Then when an episode's playback position reaches or exceeds that percentage of
///      the total episode duration, the episode is automatically marked as played
/// And  once auto-marked as played, the episode is not un-marked if the user seeks back
@MainActor
final class PlaybackCompletionTests: XCTestCase {

  private var mockService: MockEpisodePlaybackService!
  private var updatedEpisodes: [Episode] = []
  private let testEpisode = Episode(
    id: "spec-episode",
    title: "Spec Test Episode",
    podcastID: "spec-podcast",
    pubDate: Date(),
    duration: 3600, // 60 minutes
    description: "Spec scenario 5 test episode"
  )

  override func setUpWithError() throws {
    continueAfterFailure = false
    mockService = MockEpisodePlaybackService()
    updatedEpisodes = []
  }

  override func tearDownWithError() throws {
    mockService = nil
    updatedEpisodes = []
  }

  // MARK: - Helpers

  private func makeCoordinator(threshold: Double) -> EpisodePlaybackCoordinator {
    EpisodePlaybackCoordinator(
      playbackService: mockService,
      episodeLookup: { [testEpisode] id in id == testEpisode.id ? testEpisode : nil },
      episodeUpdateHandler: { [weak self] episode in self?.updatedEpisodes.append(episode) },
      playbackThreshold: threshold
    )
  }

  // MARK: - Default Threshold (95%)

  /// Spec: Default threshold is 95%.
  /// Verifies that an episode is marked played at exactly 95% of its duration
  /// when no custom threshold is configured.
  func testDefaultThresholdIs95Percent() async throws {
    // Given: A coordinator using the default 95% threshold
    let coordinator = EpisodePlaybackCoordinator(
      playbackService: mockService,
      episodeLookup: { [testEpisode] id in id == testEpisode.id ? testEpisode : nil },
      episodeUpdateHandler: { [weak self] episode in self?.updatedEpisodes.append(episode) }
    )
    defer { coordinator.stopMonitoring() }

    await coordinator.quickPlayEpisode(testEpisode)

    // When: Position reaches exactly 95% of 3600s = 3420s
    mockService.sendState(.playing(testEpisode, position: 3420, duration: 3600))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should be auto-marked as played
    XCTAssertTrue(updatedEpisodes.last?.isPlayed ?? false,
      "Default 95% threshold: episode at 95% of duration should be marked played")
  }

  /// Spec: Default threshold is 95%. Episode should NOT be marked just below it.
  func testDefaultThresholdNotTriggeredBelow95Percent() async throws {
    let coordinator = EpisodePlaybackCoordinator(
      playbackService: mockService,
      episodeLookup: { [testEpisode] id in id == testEpisode.id ? testEpisode : nil },
      episodeUpdateHandler: { [weak self] episode in self?.updatedEpisodes.append(episode) }
    )
    defer { coordinator.stopMonitoring() }

    await coordinator.quickPlayEpisode(testEpisode)

    // When: Position is at 94% of 3600s = 3384s (just below 95% threshold)
    mockService.sendState(.playing(testEpisode, position: 3384, duration: 3600))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should NOT be marked as played
    XCTAssertFalse(updatedEpisodes.last?.isPlayed ?? true,
      "94% position should not trigger 95% threshold")
  }

  // MARK: - 90% Threshold

  /// Spec: threshold choice 90% — episode marked at ≥90% of duration.
  func testNinetyPercentThresholdMarkAtBoundary() async throws {
    // Given: A coordinator with the 90% threshold option
    let coordinator = makeCoordinator(threshold: 0.90)
    defer { coordinator.stopMonitoring() }

    await coordinator.quickPlayEpisode(testEpisode)

    // When: Position reaches exactly 90% of 3600s = 3240s
    mockService.sendState(.playing(testEpisode, position: 3240, duration: 3600))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should be auto-marked as played
    XCTAssertTrue(updatedEpisodes.last?.isPlayed ?? false,
      "90% threshold: episode at exactly 90% should be marked played")
  }

  /// Spec: 90% threshold does not fire below 90%.
  func testNinetyPercentThresholdNotTriggeredBelow() async throws {
    let coordinator = makeCoordinator(threshold: 0.90)
    defer { coordinator.stopMonitoring() }

    await coordinator.quickPlayEpisode(testEpisode)

    // When: Position is at 89% of 3600s = 3204s
    mockService.sendState(.playing(testEpisode, position: 3204, duration: 3600))
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertFalse(updatedEpisodes.last?.isPlayed ?? true,
      "89% position should not trigger 90% threshold")
  }

  // MARK: - 99% Threshold

  /// Spec: threshold choice 99% — episode marked at ≥99% of duration.
  func testNinetyNinePercentThresholdMarkAtBoundary() async throws {
    // Given: A coordinator with the 99% threshold option
    let coordinator = makeCoordinator(threshold: 0.99)
    defer { coordinator.stopMonitoring() }

    await coordinator.quickPlayEpisode(testEpisode)

    // When: Position reaches exactly 99% of 3600s = 3564s
    mockService.sendState(.playing(testEpisode, position: 3564, duration: 3600))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should be auto-marked
    XCTAssertTrue(updatedEpisodes.last?.isPlayed ?? false,
      "99% threshold: episode at exactly 99% should be marked played")
  }

  /// Spec: 99% threshold does not fire at 98%.
  func testNinetyNinePercentThresholdNotTriggeredAt98Percent() async throws {
    let coordinator = makeCoordinator(threshold: 0.99)
    defer { coordinator.stopMonitoring() }

    await coordinator.quickPlayEpisode(testEpisode)

    // When: Position is at 98% of 3600s = 3528s
    mockService.sendState(.playing(testEpisode, position: 3528, duration: 3600))
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertFalse(updatedEpisodes.last?.isPlayed ?? true,
      "98% position should not trigger 99% threshold")
  }

  // MARK: - Raw Duration (Spec Clause: not adjusted for skip durations)

  /// Spec: The threshold applies to the raw episode duration, not adjusted for
  /// introSkipDuration or outroSkipDuration.
  ///
  /// A user with a 60-second outro skip who reaches 93% of a 60-minute episode
  /// with a 95% threshold does NOT trigger auto-mark.
  ///
  /// This is enforced by the coordinator using the raw `duration` from the
  /// playback state (total episode length), not a skip-adjusted value.
  func testThresholdUsesRawDurationNotSkipAdjusted() async throws {
    // Given: A 95% threshold coordinator
    let coordinator = makeCoordinator(threshold: 0.95)
    defer { coordinator.stopMonitoring() }

    await coordinator.quickPlayEpisode(testEpisode)

    // The spec example: 60-min episode with a 60s outro skip → user reaches 93% of raw
    // 93% of 3600s = 3348s — below the 95% raw threshold even though it's near the "content end"
    mockService.sendState(.playing(testEpisode, position: 3348, duration: 3600))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Should NOT trigger — raw 93% is below the 95% raw-duration threshold
    XCTAssertFalse(updatedEpisodes.last?.isPlayed ?? true,
      "93% of raw duration should not trigger 95% raw-duration threshold (spec: not skip-adjusted)")
  }

  // MARK: - Irreversibility (Spec Clause: seek-back does not unmark)

  /// Spec: Once auto-marked as played, the episode is NOT un-marked if the user
  /// seeks back to an earlier position.
  func testSeekBackDoesNotUnmarkPlayedEpisode() async throws {
    // Given: A coordinator that tracks the updated episode state
    var storedEpisode = testEpisode
    let coordinator = EpisodePlaybackCoordinator(
      playbackService: mockService,
      episodeLookup: { _ in storedEpisode },
      episodeUpdateHandler: { updated in storedEpisode = updated },
      playbackThreshold: 0.95
    )
    defer { coordinator.stopMonitoring() }

    await coordinator.quickPlayEpisode(testEpisode)

    // When: Episode reaches 95% threshold and is marked played
    mockService.sendState(.playing(testEpisode, position: 3420, duration: 3600))
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertTrue(storedEpisode.isPlayed, "Pre-condition: episode should be marked played at threshold")

    // And: User seeks back to 10% (360s)
    mockService.sendState(.playing(testEpisode, position: 360, duration: 3600))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode remains marked as played (irreversible)
    XCTAssertTrue(storedEpisode.isPlayed,
      "Seek-back to 10% should not unmark a played episode (spec: irreversible)")
  }

  /// Spec: Pause at threshold position still marks the episode as played.
  func testPausedAtThresholdMarkAsPlayed() async throws {
    let coordinator = makeCoordinator(threshold: 0.95)
    defer { coordinator.stopMonitoring() }

    await coordinator.quickPlayEpisode(testEpisode)

    // When: Episode is PAUSED at 95% (3420s of 3600s)
    mockService.sendState(.paused(testEpisode, position: 3420, duration: 3600))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Paused-at-threshold also triggers auto-mark
    XCTAssertTrue(updatedEpisodes.last?.isPlayed ?? false,
      "Pausing at the threshold position should also auto-mark as played")
  }
}

// MARK: - Mock

private class MockEpisodePlaybackService: EpisodePlaybackService {
  private let subject = PassthroughSubject<EpisodePlaybackState, Never>()

  var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
    subject.eraseToAnyPublisher()
  }

  func play(episode: Episode, duration: TimeInterval) {}

  func sendState(_ state: EpisodePlaybackState) {
    subject.send(state)
  }
}

#endif

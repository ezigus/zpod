#if os(iOS)
//
//  EpisodePlaybackCoordinatorTests.swift
//  LibraryFeatureTests
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Tests for playback coordination
//

import XCTest
import CombineSupport
@testable import LibraryFeature
import CoreModels
import PlaybackEngine

final class EpisodePlaybackCoordinatorTests: XCTestCase {

  private var coordinator: EpisodePlaybackCoordinator!
  private var mockPlaybackService: MockEpisodePlaybackService!
  private var updatedEpisodes: [Episode] = []
  private var testEpisode: Episode!

  @MainActor
  override func setUpWithError() throws {
    continueAfterFailure = false

    testEpisode = Episode(
      id: "test-episode-1",
      title: "Test Episode",
      podcastID: "test-podcast",
      pubDate: Date(),
      duration: 1800,
      description: "Test description"
    )

    updatedEpisodes = []
    mockPlaybackService = MockEpisodePlaybackService()

    coordinator = EpisodePlaybackCoordinator(
      playbackService: mockPlaybackService,
      episodeLookup: { [weak self] id in
        guard let self = self else { return nil }
        return id == self.testEpisode.id ? self.testEpisode : nil
      },
      episodeUpdateHandler: { [weak self] episode in
        self?.updatedEpisodes.append(episode)
      }
    )
  }

  @MainActor
  override func tearDownWithError() throws {
    coordinator.stopMonitoring()
    coordinator = nil
    mockPlaybackService = nil
    updatedEpisodes = []
    testEpisode = nil
  }

  // MARK: - Playback Tests

  @MainActor
  func testQuickPlayEpisode() async {
    // Given: A coordinator with playback service
    // When: Quick playing an episode
    await coordinator.quickPlayEpisode(testEpisode)

    // Then: Playback service should be called
    XCTAssertTrue(mockPlaybackService.playWasCalled)
    XCTAssertEqual(mockPlaybackService.lastPlayedEpisode?.id, testEpisode.id)
    XCTAssertEqual(mockPlaybackService.lastPlayedDuration, testEpisode.duration)
  }

  @MainActor
  func testPlaybackStateIdle() async throws {
    // Given: A coordinator monitoring playback
    await coordinator.quickPlayEpisode(testEpisode)

    // When: Receiving idle state
    mockPlaybackService.sendState(.idle(testEpisode))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should be updated with zero position
    XCTAssertFalse(updatedEpisodes.isEmpty)
    let updated = updatedEpisodes.last
    XCTAssertEqual(updated?.playbackPosition, 0)
    XCTAssertFalse(updated?.isPlayed ?? true)
  }

  @MainActor
  func testPlaybackStatePlaying() async throws {
    // Given: A coordinator monitoring playback
    await coordinator.quickPlayEpisode(testEpisode)

    // When: Receiving playing state
    mockPlaybackService.sendState(.playing(testEpisode, position: 300, duration: 1800))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should be updated with current position
    XCTAssertFalse(updatedEpisodes.isEmpty)
    let updated = updatedEpisodes.last
    XCTAssertEqual(updated?.playbackPosition, 300)
    XCTAssertFalse(updated?.isPlayed ?? true)
  }

  @MainActor
  func testPlaybackStatePaused() async throws {
    // Given: A coordinator monitoring playback
    await coordinator.quickPlayEpisode(testEpisode)

    // When: Receiving paused state
    mockPlaybackService.sendState(.paused(testEpisode, position: 600, duration: 1800))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should be updated with paused position
    XCTAssertFalse(updatedEpisodes.isEmpty)
    let updated = updatedEpisodes.last
    XCTAssertEqual(updated?.playbackPosition, 600)
    XCTAssertFalse(updated?.isPlayed ?? true)
  }

  @MainActor
  func testPlaybackStateFinished() async throws {
    // Given: A coordinator monitoring playback
    await coordinator.quickPlayEpisode(testEpisode)

    // When: Receiving finished state
    mockPlaybackService.sendState(.finished(testEpisode, duration: 1800))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should be marked as played
    XCTAssertFalse(updatedEpisodes.isEmpty)
    let updated = updatedEpisodes.last
    XCTAssertEqual(updated?.playbackPosition, 1800)
    XCTAssertTrue(updated?.isPlayed ?? false)
  }

  @MainActor
  func testStopMonitoring() async throws {
    // Given: A coordinator monitoring playback
    await coordinator.quickPlayEpisode(testEpisode)

    // When: Stopping monitoring
    coordinator.stopMonitoring()

    // And: Sending playback state
    mockPlaybackService.sendState(.playing(testEpisode, position: 300, duration: 1800))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should not be updated
    XCTAssertTrue(updatedEpisodes.isEmpty)
  }

  @MainActor
  func testNilPlaybackServiceDoesNotCrash() async {
    // Given: A coordinator with no playback service
    let nilCoordinator = EpisodePlaybackCoordinator(
      playbackService: nil,
      episodeLookup: { _ in nil },
      episodeUpdateHandler: { _ in }
    )

    // When: Attempting to quick play
    await nilCoordinator.quickPlayEpisode(testEpisode)

    // Then: Should not crash
    XCTAssertTrue(updatedEpisodes.isEmpty)
  }

  @MainActor
  func testMultiplePlaybackStateUpdates() async throws {
    // Given: A coordinator monitoring playback
    await coordinator.quickPlayEpisode(testEpisode)

    // When: Receiving multiple state updates
    mockPlaybackService.sendState(.playing(testEpisode, position: 100, duration: 1800))
    try await Task.sleep(nanoseconds: 50_000_000)

    mockPlaybackService.sendState(.playing(testEpisode, position: 200, duration: 1800))
    try await Task.sleep(nanoseconds: 50_000_000)

    mockPlaybackService.sendState(.paused(testEpisode, position: 300, duration: 1800))
    try await Task.sleep(nanoseconds: 50_000_000)

    // Then: All updates should be processed
    XCTAssertGreaterThanOrEqual(updatedEpisodes.count, 3)
    XCTAssertEqual(updatedEpisodes.last?.playbackPosition, 300)
  }

  // MARK: - Threshold Tests

  @MainActor
  func testAutoMarkAtThreshold() async throws {
    // Given: Default 95% threshold. Episode is 1800s; 95% = 1710s.
    await coordinator.quickPlayEpisode(testEpisode)

    // When: Playing at exactly the threshold position
    mockPlaybackService.sendState(.playing(testEpisode, position: 1710, duration: 1800))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should be auto-marked as played
    XCTAssertFalse(updatedEpisodes.isEmpty)
    XCTAssertTrue(updatedEpisodes.last?.isPlayed ?? false)
  }

  @MainActor
  func testNoMarkBelowThreshold() async throws {
    // Given: Default 95% threshold. 94% of 1800s = 1692s.
    await coordinator.quickPlayEpisode(testEpisode)

    // When: Playing just below the threshold
    mockPlaybackService.sendState(.playing(testEpisode, position: 1692, duration: 1800))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should NOT be marked as played
    XCTAssertFalse(updatedEpisodes.isEmpty)
    XCTAssertFalse(updatedEpisodes.last?.isPlayed ?? true)
  }

  @MainActor
  func testCustomThresholdIsRespected() async throws {
    // Given: A coordinator with a 90% threshold
    let customCoordinator = EpisodePlaybackCoordinator(
      playbackService: mockPlaybackService,
      episodeLookup: { [weak self] id in
        guard let self else { return nil }
        return id == self.testEpisode.id ? self.testEpisode : nil
      },
      episodeUpdateHandler: { [weak self] episode in
        self?.updatedEpisodes.append(episode)
      },
      playbackThreshold: 0.90
    )
    defer { customCoordinator.stopMonitoring() }

    await customCoordinator.quickPlayEpisode(testEpisode)

    // When: Playing at 90% of 1800s = 1620s
    mockPlaybackService.sendState(.playing(testEpisode, position: 1620, duration: 1800))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should be marked as played at the 90% threshold
    XCTAssertFalse(updatedEpisodes.isEmpty)
    XCTAssertTrue(updatedEpisodes.last?.isPlayed ?? false)
  }

  @MainActor
  func testSeekBackDoesNotUnmarkPlayed() async throws {
    // Given: Coordinator where lookup tracks the updated episode state (simulating real persistence)
    var storedEpisode = testEpisode!
    let trackingCoordinator = EpisodePlaybackCoordinator(
      playbackService: mockPlaybackService,
      episodeLookup: { _ in storedEpisode },
      episodeUpdateHandler: { updated in storedEpisode = updated },
      playbackThreshold: 0.95
    )
    defer { trackingCoordinator.stopMonitoring() }

    await trackingCoordinator.quickPlayEpisode(testEpisode)

    // When: Position reaches threshold, episode is marked played
    mockPlaybackService.sendState(.playing(testEpisode, position: 1710, duration: 1800))
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertTrue(storedEpisode.isPlayed, "Episode should be marked played at threshold")

    // And: User seeks back to 50%
    mockPlaybackService.sendState(.playing(testEpisode, position: 900, duration: 1800))
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then: Episode should still be marked as played (irreversible)
    XCTAssertTrue(storedEpisode.isPlayed, "Seeking back should not unmark played status")
  }
}

// MARK: - Mock Playback Service

private class MockEpisodePlaybackService: EpisodePlaybackService {
  var playWasCalled = false
  var lastPlayedEpisode: Episode?
  var lastPlayedDuration: TimeInterval?

  private let stateSubject = PassthroughSubject<EpisodePlaybackState, Never>()

  var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  func play(episode: Episode, duration: TimeInterval) {
    playWasCalled = true
    lastPlayedEpisode = episode
    lastPlayedDuration = duration
  }

  func sendState(_ state: EpisodePlaybackState) {
    stateSubject.send(state)
  }
}

#endif

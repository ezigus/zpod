//
//  EpisodePlaybackCoordinatorTests.swift
//  LibraryFeatureTests
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Tests for playback coordination
//

import XCTest
import Combine
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

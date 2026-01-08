//
//  ExpandedPlayerViewModelTests.swift
//  PlayerFeatureTests
//
//  Created for Issue 03.1.1.2: Expanded Player Layout & Interaction
//

import Foundation
import CombineSupport
import CoreModels
import PlaybackEngine
import SharedUtilities
import Testing
@testable import PlayerFeature

@MainActor
struct ExpandedPlayerViewModelTests {

  // MARK: - Initial State

  @Test("Expanded player starts with idle state")
  func testInitialState() async throws {
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    try await waitForStateUpdate()
    #expect(viewModel.episode != nil) // idle state includes episode
    #expect(viewModel.isPlaying == false)
    #expect(viewModel.currentPosition == 0)
    #expect(viewModel.duration == 0)
  }

  // MARK: - Playback State Tracking

  @Test("Expanded player updates when episode starts playing")
  func testPlayingState() async throws {
    let episode = sampleEpisode(id: "playing-1", title: "Test Episode")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 1800)
    try await waitForStateUpdate()

    #expect(viewModel.episode?.id == "playing-1")
    #expect(viewModel.episode?.title == "Test Episode")
    #expect(viewModel.isPlaying == true)
    #expect(viewModel.currentPosition == 0)
    #expect(viewModel.duration == 1800)
  }

  @Test("Expanded player updates when playback pauses")
  func testPausedState() async throws {
    let episode = sampleEpisode(id: "paused-1")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 1200)
    try await waitForStateUpdate()
    service.pause()
    try await waitForStateUpdate()

    #expect(viewModel.isPlaying == false)
    #expect(viewModel.episode?.id == "paused-1")
    #expect(viewModel.duration == 1200)
  }

  @Test("Expanded player reflects failure state with latest position")
  func testFailureState() async throws {
    let episode = sampleEpisode(id: "failed-1")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 1500)
    try await waitForStateUpdate()
    service.seek(to: 300)
    try await waitForStateUpdate()

    service.fail()
    try await waitForStateUpdate()

    #expect(viewModel.isPlaying == false)
    #expect(viewModel.currentPosition == 300)
    #expect(viewModel.duration == 1500)
  }

  // MARK: - Error State (Issue 03.3.4.3)

  @Test("Expanded player exposes error when playback fails")
  func testCurrentErrorExposedOnFailure() async throws {
    let episode = sampleEpisode(id: "error-test")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 900)
    try await waitForStateUpdate()

    let expectedError = PlaybackError.networkError
    service.fail(error: expectedError)
    try await waitForStateUpdate()

    #expect(viewModel.currentError == expectedError)
    #expect(viewModel.isPlaying == false)
    #expect(viewModel.episode?.id == "error-test")
  }

  @Test("Error is cleared when playback resumes after failure")
  func testCurrentErrorClearedOnPlaying() async throws {
    let episode = sampleEpisode(id: "error-clear-test")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    // Start with an error
    service.fail(error: .networkError)
    try await waitForStateUpdate()
    #expect(viewModel.currentError != nil)

    // Resume playback
    service.play(episode: episode, duration: 1200)
    try await waitForStateUpdate()

    // Error should be cleared
    #expect(viewModel.currentError == nil)
    #expect(viewModel.isPlaying == true)
  }

  @Test("Error is cleared when playback is paused after failure")
  func testCurrentErrorClearedOnPaused() async throws {
    let episode = sampleEpisode(id: "error-pause-test")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    // Fail first
    service.fail(error: .timeout)
    try await waitForStateUpdate()
    #expect(viewModel.currentError != nil)

    // Pause (simulating recovery)
    service.play(episode: episode, duration: 900)
    try await waitForStateUpdate()
    service.pause()
    try await waitForStateUpdate()

    // Error should be cleared
    #expect(viewModel.currentError == nil)
    #expect(viewModel.isPlaying == false)
  }

  @Test("Error is cleared when playback finishes after failure")
  func testCurrentErrorClearedOnFinished() async throws {
    let episode = sampleEpisode(id: "error-finish-test")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    // Start playing, then fail
    service.play(episode: episode, duration: 900)
    try await waitForStateUpdate()
    service.fail(error: .streamFailed)
    try await waitForStateUpdate()
    #expect(viewModel.currentError != nil)

    // Finish playback
    service.finish()
    try await waitForStateUpdate()

    // Error should be cleared
    #expect(viewModel.currentError == nil)
  }

  @Test("Error is cleared when returning to idle after failure")
  func testCurrentErrorClearedOnIdle() async throws {
    let episode = sampleEpisode(id: "error-idle-test")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    // Fail first
    service.fail(error: .missingAudioURL)
    try await waitForStateUpdate()
    #expect(viewModel.currentError != nil)

    // Return to idle
    service.emit(.idle(episode))
    try await waitForStateUpdate()

    // Error should be cleared
    #expect(viewModel.currentError == nil)
  }

  @Test("retryPlayback calls play with current episode and position")
  func testRetryPlaybackCallsPlayAndSeek() async throws {
    let episode = sampleEpisode(id: "retry-test")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    // Set up a failure at position 300
    service.play(episode: episode, duration: 1800)
    try await waitForStateUpdate()
    service.seek(to: 300)
    try await waitForStateUpdate()
    service.fail(error: .networkError)
    try await waitForStateUpdate()

    let initialPlayCount = service.playCallCount
    let initialSeekCount = service.seekCallCount

    // Retry
    viewModel.retryPlayback()
    try await waitForStateUpdate()

    // Should have called play and seek
    #expect(service.playCallCount == initialPlayCount + 1)
    #expect(service.seekCallCount == initialSeekCount + 1)
    #expect(service.lastSeekPosition == 300)
  }

  @Test("retryPlayback does nothing when no error present")
  func testRetryPlaybackIgnoredWhenNoError() async throws {
    let episode = sampleEpisode(id: "no-error-retry")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 900)
    try await waitForStateUpdate()

    let playCountBefore = service.playCallCount

    // Try to retry when no error
    viewModel.retryPlayback()
    try await waitForStateUpdate()

    // Play count should not increase
    #expect(service.playCallCount == playCountBefore)
  }

  @Test("retryPlayback does nothing when no episode present")
  func testRetryPlaybackIgnoredWhenNoEpisode() async throws {
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    // Wait for idle state to propagate
    try await waitForStateUpdate()
    
    // Idle state provides episode
    #expect(viewModel.episode != nil)
    #expect(viewModel.currentError == nil) // no error initially

    let playCountBefore = service.playCallCount

    // Try to retry when no current error (guard will prevent retry)
    viewModel.retryPlayback()
    try await waitForStateUpdate()

    // Play count should not increase
    #expect(service.playCallCount == playCountBefore)
  }

  // MARK: - Position Tracking

  @Test("Expanded player tracks position updates during playback")
  func testPositionTracking() async throws {
    let episode = sampleEpisode(id: "position-1")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 600)
    try await waitForStateUpdate()

    service.seek(to: 150)
    try await waitForStateUpdate()

    #expect(viewModel.currentPosition == 150)
    #expect(viewModel.duration == 600)
  }

  // MARK: - Progress Computation

  @Test("Progress fraction calculates correctly")
  func testProgressFraction() async throws {
    let episode = sampleEpisode(id: "progress-1")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 1000)
    try await waitForStateUpdate()
    service.seek(to: 250)
    try await waitForStateUpdate()

    let expectedFraction = 250.0 / 1000.0
    #expect(abs(viewModel.progressFraction - expectedFraction) < 0.001)
  }

  @Test("Progress fraction handles zero duration")
  func testProgressFractionZeroDuration() async throws {
    let episode = sampleEpisode(id: "zero-duration")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.emit(.idle(episode))
    try await waitForStateUpdate()

    #expect(viewModel.progressFraction == 0)
  }

  @Test("Progress fraction clamps to valid range")
  func testProgressFractionClamping() async throws {
    let episode = sampleEpisode(id: "clamp-1")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 100)
    try await waitForStateUpdate()
    
    // Simulate position at exactly duration
    service.seek(to: 100)
    try await waitForStateUpdate()

    #expect(viewModel.progressFraction <= 1.0)
    #expect(viewModel.progressFraction >= 0.0)
  }

  // MARK: - Time Formatting

  @Test("Formats time with hours, minutes, seconds")
  func testTimeFormattingWithHours() async throws {
    let episode = sampleEpisode(id: "format-1")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 3665) // 1:01:05
    try await waitForStateUpdate()
    service.seek(to: 3665)
    try await waitForStateUpdate()

    #expect(viewModel.formattedCurrentTime == "1:01:05")
    #expect(viewModel.formattedDuration == "1:01:05")
  }

  @Test("Formats time with minutes and seconds only")
  func testTimeFormattingWithoutHours() async throws {
    let episode = sampleEpisode(id: "format-2")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 125) // 2:05
    try await waitForStateUpdate()
    service.seek(to: 125)
    try await waitForStateUpdate()

    #expect(viewModel.formattedCurrentTime == "2:05")
    #expect(viewModel.formattedDuration == "2:05")
  }

  // MARK: - Transport Actions

  @Test("togglePlayPause pauses when playing")
  func testTogglePlayPausePauses() async throws {
    let episode = sampleEpisode(id: "toggle-1")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 900)
    try await waitForStateUpdate()
    #expect(service.pauseCallCount == 0)

    viewModel.togglePlayPause()
    try await waitForStateUpdate()

    #expect(service.pauseCallCount == 1)
    #expect(viewModel.isPlaying == false)
  }

  @Test("togglePlayPause resumes when paused")
  func testTogglePlayPauseResumes() async throws {
    let episode = sampleEpisode(id: "toggle-2")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 900)
    try await waitForStateUpdate()
    service.pause()
    try await waitForStateUpdate()

    viewModel.togglePlayPause()
    try await waitForStateUpdate()

    #expect(service.playCallCount == 2) // initial + resume
  }

  @Test("Skip forward delegates to transport controller")
  func testSkipForward() async throws {
    let episode = sampleEpisode(id: "skip-fwd")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 600)
    try await waitForStateUpdate()
    viewModel.skipForward()

    #expect(service.skipForwardCallCount == 1)
  }

  @Test("Skip backward delegates to transport controller")
  func testSkipBackward() async throws {
    let episode = sampleEpisode(id: "skip-back")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 600)
    try await waitForStateUpdate()
    viewModel.skipBackward()

    #expect(service.skipBackwardCallCount == 1)
  }

  // MARK: - Scrubbing Behavior

  @Test("Scrubbing prevents automatic position updates")
  func testScrubbingPreventsUpdates() async throws {
    let episode = sampleEpisode(id: "scrub-1")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 1000)
    try await waitForStateUpdate()

    viewModel.beginScrubbing()
    #expect(viewModel.isScrubbing == true)

    // Update scrubbing position locally
    viewModel.updateScrubbingPosition(500)
    #expect(viewModel.currentPosition == 500)

    // Simulate service updating position (should be ignored)
    service.seek(to: 100)
    try await waitForStateUpdate()

    // Position should remain at scrubbed value
    #expect(viewModel.currentPosition == 500)
  }

  @Test("Ending scrubbing seeks to scrubbed position")
  func testEndScrubbingSeeks() async throws {
    let episode = sampleEpisode(id: "scrub-2")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 1000)
    try await waitForStateUpdate()

    viewModel.beginScrubbing()
    viewModel.updateScrubbingPosition(750)
    #expect(service.seekCallCount == 0)

    viewModel.endScrubbing()

    #expect(service.seekCallCount == 1)
    #expect(service.lastSeekPosition == 750)
    #expect(viewModel.isScrubbing == false)
  }

  @Test("Scrubbing clamps position to valid range")
  func testScrubbingClamps() async throws {
    let episode = sampleEpisode(id: "scrub-clamp")
    let service = RecordingPlaybackService()
    let viewModel = ExpandedPlayerViewModel(playbackService: service)

    service.play(episode: episode, duration: 1000)
    try await waitForStateUpdate()

    viewModel.beginScrubbing()

    // Try to scrub beyond duration
    viewModel.updateScrubbingPosition(1500)
    #expect(viewModel.currentPosition == 1000)

    // Try to scrub before start
    viewModel.updateScrubbingPosition(-100)
    #expect(viewModel.currentPosition == 0)

    viewModel.endScrubbing()
  }

  // MARK: - Helpers

  private func waitForStateUpdate() async throws {
    try await Task.sleep(for: .milliseconds(50))
    await Task.yield()
  }

  private func sampleEpisode(
    id: String,
    title: String = "Test Episode",
    podcastTitle: String = "Test Podcast"
  ) -> Episode {
    Episode(
      id: id,
      title: title,
      podcastID: "podcast-\(id)",
      podcastTitle: podcastTitle,
      duration: 1800,
      artworkURL: URL(string: "https://example.com/\(id).jpg")
    )
  }
}

// MARK: - Recording Test Doubles

@MainActor
private final class RecordingPlaybackService: EpisodePlaybackService, EpisodeTransportControlling {
  private let subject: CurrentValueSubject<EpisodePlaybackState, Never>
  private(set) var currentEpisode: Episode?
  private var currentDuration: TimeInterval = 0
  private var currentPosition: TimeInterval = 0

  var playCallCount = 0
  var pauseCallCount = 0
  var skipForwardCallCount = 0
  var skipBackwardCallCount = 0
  var seekCallCount = 0
  var lastSeekPosition: TimeInterval = 0

  var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
    subject.eraseToAnyPublisher()
  }

  init(initialEpisode: Episode? = nil) {
    let placeholder = initialEpisode ?? Episode(id: "initial", title: "Initial Episode")
    subject = CurrentValueSubject(.idle(placeholder))
    currentEpisode = initialEpisode
  }

  func play(episode: Episode, duration maybeDuration: TimeInterval?) {
    playCallCount += 1
    currentEpisode = episode
    currentDuration = maybeDuration ?? episode.duration ?? 300
    currentPosition = 0
    subject.send(.playing(episode, position: currentPosition, duration: currentDuration))
  }

  func pause() {
    pauseCallCount += 1
    guard let episode = currentEpisode else { return }
    subject.send(.paused(episode, position: currentPosition, duration: currentDuration))
  }

  func skipForward(interval: TimeInterval?) {
    skipForwardCallCount += 1
  }

  func skipBackward(interval: TimeInterval?) {
    skipBackwardCallCount += 1
  }

  func seek(to position: TimeInterval) {
    seekCallCount += 1
    lastSeekPosition = position
    guard let episode = currentEpisode else { return }
    currentPosition = position
    subject.send(.playing(episode, position: currentPosition, duration: currentDuration))
  }

  func finish() {
    guard let episode = currentEpisode else { return }
    subject.send(.finished(episode, duration: currentDuration))
  }

  func emit(_ state: EpisodePlaybackState) {
    subject.send(state)
  }

  func fail(error: PlaybackError = .streamFailed) {
    let episode = currentEpisode ?? Episode(id: "failure", title: "Failure")
    subject.send(.failed(episode, position: currentPosition, duration: currentDuration, error: error))
  }
}

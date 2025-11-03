//
//  MiniPlayerViewModelTests.swift
//  PlayerFeatureTests
//
//  Created for Issue 03.1.1.1: Mini-Player Foundation
//

import Foundation
import CombineSupport
import CoreModels
import PlaybackEngine
import Testing
@testable import PlayerFeature

@MainActor
struct MiniPlayerViewModelTests {

  // MARK: - Visibility State -------------------------------------------------

  @Test("Mini player starts hidden when playback is idle")
  func testInitialStateHidden() async throws {
    let service = RecordingPlaybackService()
    let viewModel = MiniPlayerViewModel(
      playbackService: service
    )

    try await waitForStateUpdate()
    #expect(viewModel.displayState.isVisible == false)
    #expect(viewModel.displayState.episode == nil)
  }

  @Test("Mini player becomes visible when an episode is playing")
  func testShowsWhenPlaying() async throws {
    let episode = sampleEpisode(id: "playing-1")
    let service = RecordingPlaybackService()
    let viewModel = MiniPlayerViewModel(
      playbackService: service
    )

    service.play(episode: episode, duration: 1800)
    try await waitForStateUpdate()

    #expect(viewModel.displayState.isVisible == true)
    #expect(viewModel.displayState.isPlaying == true)
    #expect(viewModel.displayState.episode?.id == "playing-1")
    #expect(viewModel.displayState.duration == 1800)
  }

  @Test("Mini player remains visible when playback pauses")
  func testShowsWhenPaused() async throws {
    let episode = sampleEpisode(id: "paused-1")
    let service = RecordingPlaybackService()
    let viewModel = MiniPlayerViewModel(
      playbackService: service
    )

    service.play(episode: episode, duration: 1200)
    try await waitForStateUpdate()
    service.pause()
    try await waitForStateUpdate()

    #expect(viewModel.displayState.isVisible == true)
    #expect(viewModel.displayState.isPlaying == false)
    #expect(viewModel.displayState.episode?.id == "paused-1")
  }

  @Test("Mini player hides when playback returns to idle")
  func testHidesWhenIdle() async throws {
    let episode = sampleEpisode(id: "idle-1")
    let service = RecordingPlaybackService(initialEpisode: episode)
    let viewModel = MiniPlayerViewModel(
      playbackService: service
    )

    service.emit(.idle(episode))
    try await waitForStateUpdate()

    #expect(viewModel.displayState.isVisible == false)
    #expect(viewModel.displayState.isPlaying == false)
  }

  @Test("Mini player hides when playback finishes and queue is empty")
  func testHidesWhenFinishedWithEmptyQueue() async throws {
    let episode = sampleEpisode(id: "finished-1")
    let service = RecordingPlaybackService()
    let viewModel = MiniPlayerViewModel(
      playbackService: service,
      queueIsEmpty: { true }
    )

    service.play(episode: episode, duration: 100)
    try await waitForStateUpdate()

    service.finish()
    try await waitForStateUpdate()

    #expect(viewModel.displayState.isVisible == false)
    #expect(viewModel.displayState.isPlaying == false)
  }

  @Test("Mini player stays visible on finish when queue has episodes")
  func testFinishedStaysVisibleWhenQueueHasEpisodes() async throws {
    let episode = sampleEpisode(id: "finished-queued")
    let service = RecordingPlaybackService()
    var queueEmpty = false
    let viewModel = MiniPlayerViewModel(
      playbackService: service,
      queueIsEmpty: { queueEmpty }
    )

    service.play(episode: episode, duration: 100)
    try await waitForStateUpdate()

    queueEmpty = false
    service.finish()
    try await waitForStateUpdate()

    #expect(viewModel.displayState.isVisible == true)
    #expect(viewModel.displayState.isPlaying == false)
    #expect(viewModel.displayState.currentPosition == 100)
  }

  // MARK: - Transport Actions ------------------------------------------------

  @Test("togglePlayPause pauses when currently playing")
  func testTogglePlayPausePauses() async throws {
    let episode = sampleEpisode(id: "toggle-1")
    let service = RecordingPlaybackService()
    let viewModel = MiniPlayerViewModel(
      playbackService: service
    )

    service.play(episode: episode, duration: 900)
    try await waitForStateUpdate()
    #expect(service.pauseCallCount == 0)

    viewModel.togglePlayPause()
    try await waitForStateUpdate()

    #expect(service.pauseCallCount == 1)
    #expect(viewModel.displayState.isPlaying == false)
  }

  @Test("togglePlayPause resumes playback when paused")
  func testTogglePlayPauseResumes() async throws {
    let episode = sampleEpisode(id: "toggle-2")
    let service = RecordingPlaybackService()
    let viewModel = MiniPlayerViewModel(
      playbackService: service
    )

    service.play(episode: episode, duration: 900)
    try await waitForStateUpdate()
    service.pause()
    try await waitForStateUpdate()

    viewModel.togglePlayPause()
    try await waitForStateUpdate()

    #expect(service.playCallCount == 2) // initial + resume
    #expect(viewModel.displayState.isPlaying == true)
  }

  @Test("Skip forward delegates to transport controller")
  func testSkipForwardDelegates() async throws {
    let episode = sampleEpisode(id: "skip-forward")
    let service = RecordingPlaybackService()
    let viewModel = MiniPlayerViewModel(
      playbackService: service
    )

    service.play(episode: episode, duration: 600)
    try await waitForStateUpdate()
    viewModel.skipForward()

    #expect(service.skipForwardCallCount == 1)
  }

  @Test("Skip backward delegates to transport controller")
  func testSkipBackwardDelegates() async throws {
    let episode = sampleEpisode(id: "skip-back")
    let service = RecordingPlaybackService()
    let viewModel = MiniPlayerViewModel(
      playbackService: service
    )

    service.play(episode: episode, duration: 600)
    try await waitForStateUpdate()
    viewModel.skipBackward()

    #expect(service.skipBackwardCallCount == 1)
  }

  // MARK: - Metadata ---------------------------------------------------------

  @Test("Mini player updates metadata when new episode begins")
  func testEpisodeMetadataUpdates() async throws {
    let service = RecordingPlaybackService()
    let viewModel = MiniPlayerViewModel(
      playbackService: service
    )

    let first = sampleEpisode(id: "metadata-1", title: "First Episode", podcastTitle: "Podcast One")
    service.play(episode: first, duration: 1200)
    try await waitForStateUpdate()

    #expect(viewModel.displayState.episode?.title == "First Episode")
    #expect(viewModel.displayState.duration == 1200)

    let second = sampleEpisode(id: "metadata-2", title: "Second Episode", podcastTitle: "Podcast Two")
    service.play(episode: second, duration: 1800)
    try await waitForStateUpdate()

    #expect(viewModel.displayState.episode?.title == "Second Episode")
    #expect(viewModel.displayState.episode?.podcastTitle == "Podcast Two")
    #expect(viewModel.displayState.duration == 1800)
  }

  // MARK: - Helpers ----------------------------------------------------------

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

// MARK: - Recording Test Doubles ---------------------------------------------

@MainActor
private final class RecordingPlaybackService: EpisodePlaybackService, EpisodeTransportControlling {
  private let subject: CurrentValueSubject<EpisodePlaybackState, Never>
  private(set) var currentEpisode: Episode?
  private var currentDuration: TimeInterval = 0

  var playCallCount = 0
  var pauseCallCount = 0
  var skipForwardCallCount = 0
  var skipBackwardCallCount = 0

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
    subject.send(.playing(episode, position: 0, duration: currentDuration))
  }

  func pause() {
    pauseCallCount += 1
    guard let episode = currentEpisode else { return }
    subject.send(.paused(episode, position: 0, duration: currentDuration))
  }

  func skipForward(interval: TimeInterval?) {
    skipForwardCallCount += 1
  }

  func skipBackward(interval: TimeInterval?) {
    skipBackwardCallCount += 1
  }

  func seek(to position: TimeInterval) {
    guard let episode = currentEpisode else { return }
    subject.send(.playing(episode, position: position, duration: currentDuration))
  }

  func finish() {
    guard let episode = currentEpisode else { return }
    subject.send(.finished(episode, duration: currentDuration))
  }

  func emit(_ state: EpisodePlaybackState) {
    subject.send(state)
  }
}

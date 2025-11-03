//
//  MiniPlayerViewModelTests.swift
//  PlayerFeatureTests
//
//  Created for Issue 03.1.1.1: Mini-Player Foundation
//

import Combine
import CoreModels
import PlaybackEngine
import Testing
@testable import PlayerFeature

@MainActor
struct MiniPlayerViewModelTests {
  
  // MARK: - Initial State Tests
  
  @Test("MiniPlayerViewModel initializes with idle state")
  func testInitialState() async {
    let stubPlayer = StubEpisodePlayer(ticker: TimerTicker())
    let viewModel = MiniPlayerViewModel(playbackService: stubPlayer)
    
    // Give the publisher time to emit initial state
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.isPlaying == false)
    #expect(viewModel.isVisible == false)
    #expect(viewModel.currentPosition == 0)
  }
  
  // MARK: - Playback State Tests
  
  @Test("MiniPlayerViewModel shows when episode is playing")
  func testShowsWhenPlaying() async {
    let stubPlayer = StubEpisodePlayer(ticker: TimerTicker())
    let viewModel = MiniPlayerViewModel(playbackService: stubPlayer)
    
    let episode = Episode(
      id: "test-1",
      title: "Test Episode",
      podcastID: "podcast-1",
      podcastTitle: "Test Podcast",
      duration: 1800
    )
    
    stubPlayer.play(episode: episode, duration: 1800)
    
    // Give the publisher time to emit
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.isVisible == true)
    #expect(viewModel.isPlaying == true)
    #expect(viewModel.currentEpisode?.id == "test-1")
    #expect(viewModel.duration == 1800)
  }
  
  @Test("MiniPlayerViewModel shows when episode is paused")
  func testShowsWhenPaused() async {
    let stubPlayer = StubEpisodePlayer(ticker: TimerTicker())
    let viewModel = MiniPlayerViewModel(playbackService: stubPlayer)
    
    let episode = Episode(
      id: "test-2",
      title: "Test Episode",
      podcastID: "podcast-1",
      podcastTitle: "Test Podcast",
      duration: 1800
    )
    
    stubPlayer.play(episode: episode, duration: 1800)
    try? await Task.sleep(for: .milliseconds(100))
    
    stubPlayer.pause()
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.isVisible == true)
    #expect(viewModel.isPlaying == false)
    #expect(viewModel.currentEpisode?.id == "test-2")
  }
  
  @Test("MiniPlayerViewModel hides when idle")
  func testHidesWhenIdle() async {
    let episode = Episode(
      id: "test-3",
      title: "Test Episode",
      podcastID: "podcast-1",
      podcastTitle: "Test Podcast",
      duration: 1800
    )
    
    let stubPlayer = StubEpisodePlayer(initialEpisode: episode, ticker: TimerTicker())
    let viewModel = MiniPlayerViewModel(playbackService: stubPlayer)
    
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.isVisible == false)
    #expect(viewModel.isPlaying == false)
  }
  
  // MARK: - Control Action Tests
  
  @Test("togglePlayPause pauses when playing")
  func testTogglePlayPausePauses() async {
    let stubPlayer = StubEpisodePlayer(ticker: TimerTicker())
    let viewModel = MiniPlayerViewModel(playbackService: stubPlayer)
    
    let episode = Episode(
      id: "test-4",
      title: "Test Episode",
      podcastID: "podcast-1",
      podcastTitle: "Test Podcast",
      duration: 1800
    )
    
    stubPlayer.play(episode: episode, duration: 1800)
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.isPlaying == true)
    
    viewModel.togglePlayPause()
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.isPlaying == false)
  }
  
  @Test("togglePlayPause resumes when paused")
  func testTogglePlayPauseResumes() async {
    let stubPlayer = StubEpisodePlayer(ticker: TimerTicker())
    let viewModel = MiniPlayerViewModel(playbackService: stubPlayer)
    
    let episode = Episode(
      id: "test-5",
      title: "Test Episode",
      podcastID: "podcast-1",
      podcastTitle: "Test Podcast",
      duration: 1800
    )
    
    stubPlayer.play(episode: episode, duration: 1800)
    try? await Task.sleep(for: .milliseconds(100))
    
    stubPlayer.pause()
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.isPlaying == false)
    
    viewModel.togglePlayPause()
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.isPlaying == true)
  }
  
  // MARK: - Episode Metadata Tests
  
  @Test("MiniPlayerViewModel updates episode metadata")
  func testUpdatesEpisodeMetadata() async {
    let stubPlayer = StubEpisodePlayer(ticker: TimerTicker())
    let viewModel = MiniPlayerViewModel(playbackService: stubPlayer)
    
    let episode1 = Episode(
      id: "ep-1",
      title: "First Episode",
      podcastID: "podcast-1",
      podcastTitle: "Podcast One",
      duration: 1200
    )
    
    stubPlayer.play(episode: episode1, duration: 1200)
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.currentEpisode?.title == "First Episode")
    #expect(viewModel.duration == 1200)
    
    let episode2 = Episode(
      id: "ep-2",
      title: "Second Episode",
      podcastID: "podcast-2",
      podcastTitle: "Podcast Two",
      duration: 1800
    )
    
    stubPlayer.play(episode: episode2, duration: 1800)
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.currentEpisode?.title == "Second Episode")
    #expect(viewModel.duration == 1800)
  }
  
  // MARK: - Finished State Tests
  
  @Test("MiniPlayerViewModel remains visible when episode finishes")
  func testRemainsVisibleWhenFinished() async {
    let episode = Episode(
      id: "test-finished",
      title: "Finished Episode",
      podcastID: "podcast-1",
      podcastTitle: "Test Podcast",
      duration: 100
    )
    
    // Create a custom stub that can emit finished state
    let stubPlayer = FinishableStubPlayer(initialEpisode: episode, ticker: TimerTicker())
    let viewModel = MiniPlayerViewModel(playbackService: stubPlayer)
    
    stubPlayer.play(episode: episode, duration: 100)
    try? await Task.sleep(for: .milliseconds(100))
    
    stubPlayer.finish()
    try? await Task.sleep(for: .milliseconds(100))
    
    #expect(viewModel.isVisible == true)
    #expect(viewModel.isPlaying == false)
    #expect(viewModel.currentPosition == 100)
  }
}

// MARK: - Test Helpers

/// Extended stub player that can emit finished state for testing
@MainActor
private final class FinishableStubPlayer: EpisodePlaybackService {
  private let subject: CurrentValueSubject<EpisodePlaybackState, Never>
  
  var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
    subject.eraseToAnyPublisher()
  }
  
  private let ticker: Ticker
  private var currentEpisode: Episode
  
  init(initialEpisode: Episode? = nil, ticker: Ticker) {
    let ep = initialEpisode ?? Episode(id: "stub", title: "Stub", description: "Stub episode")
    self.currentEpisode = ep
    self.ticker = ticker
    self.subject = CurrentValueSubject(.idle(ep))
  }
  
  func play(episode: Episode, duration maybeDuration: TimeInterval?) {
    let normalized = (maybeDuration ?? 300) > 0 ? (maybeDuration ?? 300) : 300
    currentEpisode = episode
    subject.send(.playing(episode, position: 0, duration: normalized))
  }
  
  func pause() {
    subject.send(.paused(currentEpisode, position: 0, duration: 300))
  }
  
  func finish() {
    let duration = currentEpisode.duration ?? 300
    subject.send(.finished(currentEpisode, duration: duration))
  }
}

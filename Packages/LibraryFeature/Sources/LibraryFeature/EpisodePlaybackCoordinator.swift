//
//  EpisodePlaybackCoordinator.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Extracts playback state management and episode position tracking
//

import Combine
import CoreModels
import Foundation
import PlaybackEngine

// MARK: - Protocol

/// Coordinates episode playback and state synchronization
@MainActor
public protocol EpisodePlaybackCoordinating: AnyObject {
  /// Quick play an episode
  func quickPlayEpisode(_ episode: Episode) async
  
  /// Stop monitoring playback state
  func stopMonitoring()
}

// MARK: - Implementation

/// Default implementation of playback coordination
@MainActor
public final class EpisodePlaybackCoordinator: EpisodePlaybackCoordinating {
  private let playbackService: EpisodePlaybackService?
  private let episodeLookup: (String) -> Episode?
  private let episodeUpdateHandler: (Episode) -> Void
  private var playbackStateCancellable: AnyCancellable?
  
  public init(
    playbackService: EpisodePlaybackService?,
    episodeLookup: @escaping (String) -> Episode?,
    episodeUpdateHandler: @escaping (Episode) -> Void
  ) {
    self.playbackService = playbackService
    self.episodeLookup = episodeLookup
    self.episodeUpdateHandler = episodeUpdateHandler
  }
  
  public func quickPlayEpisode(_ episode: Episode) async {
    guard let playbackService else { return }
    
    #if canImport(Combine)
      playbackStateCancellable?.cancel()
      playbackStateCancellable = playbackService.statePublisher
        .receive(on: DispatchQueue.main)
        .sink { [weak self] state in
          self?.handlePlaybackState(state)
        }
    #endif
    
    playbackService.play(episode: episode, duration: episode.duration)
  }
  
  public func stopMonitoring() {
    playbackStateCancellable?.cancel()
    playbackStateCancellable = nil
  }
  
  // MARK: - Private Methods
  
  private func handlePlaybackState(_ state: EpisodePlaybackState) {
    switch state {
    case .idle(let episode):
      updateEpisodePlayback(for: episode, position: 0, markPlayed: false)
    case .playing(let episode, let position, duration: _):
      updateEpisodePlayback(for: episode, position: position, markPlayed: false)
    case .paused(let episode, let position, duration: _):
      updateEpisodePlayback(for: episode, position: position, markPlayed: false)
    case .finished(let episode, let duration):
      updateEpisodePlayback(for: episode, position: duration, markPlayed: true)
    }
  }
  
  private func updateEpisodePlayback(for episode: Episode, position: TimeInterval, markPlayed: Bool) {
    guard var storedEpisode = episodeLookup(episode.id) else { return }
    storedEpisode = storedEpisode.withPlaybackPosition(Int(position))
    if markPlayed {
      storedEpisode = storedEpisode.withPlayedStatus(true)
    }
    episodeUpdateHandler(storedEpisode)
  }
}

//
//  EpisodePlaybackCoordinator.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Extracts playback state management and episode position tracking
//

import CombineSupport
import CoreModels
import Foundation
import PlaybackEngine
import SharedUtilities

// MARK: - Protocol

/// Coordinates episode playback and state synchronization
@MainActor
public protocol EpisodePlaybackCoordinating: AnyObject {
  /// Quick play an episode
  func quickPlayEpisode(_ episode: Episode)

  /// Stop monitoring playback state
  func stopMonitoring()

  /// Update the completion threshold used to auto-mark episodes as played
  func updatePlaybackThreshold(_ threshold: Double)
}

// MARK: - Implementation

/// Default implementation of playback coordination
@MainActor
public final class EpisodePlaybackCoordinator: EpisodePlaybackCoordinating {
  private let playbackService: EpisodePlaybackService?
  private let episodeLookup: (String) -> Episode?
  private let episodeUpdateHandler: (Episode) -> Void
  private var playbackThreshold: Double
  private var playbackStateCancellable: AnyCancellable?

  public init(
    playbackService: EpisodePlaybackService?,
    episodeLookup: @escaping (String) -> Episode?,
    episodeUpdateHandler: @escaping (Episode) -> Void,
    playbackThreshold: Double = 0.95
  ) {
    self.playbackService = playbackService
    self.episodeLookup = episodeLookup
    self.episodeUpdateHandler = episodeUpdateHandler
    self.playbackThreshold = playbackThreshold
  }

  public func quickPlayEpisode(_ episode: Episode) {
    guard let playbackService else {
      PlaybackEnvironment.playbackStateCoordinator?.reportPlaybackError(
        .streamFailed,
        retryAction: { [weak self] in
          guard let self else { return }
          Task { self.quickPlayEpisode(episode) }
        }
      )
      return
    }

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

  public func updatePlaybackThreshold(_ threshold: Double) {
    playbackThreshold = threshold
  }

  // MARK: - Private Methods

  private func handlePlaybackState(_ state: EpisodePlaybackState) {
    switch state {
    case .idle(let episode):
      updateEpisodePlayback(for: episode, position: 0, markPlayed: false)
    case .playing(let episode, let position, let duration):
      let markPlayed = duration > 0 && position >= playbackThreshold * duration
      updateEpisodePlayback(for: episode, position: position, markPlayed: markPlayed)
    case .paused(let episode, let position, let duration):
      let markPlayed = duration > 0 && position >= playbackThreshold * duration
      updateEpisodePlayback(for: episode, position: position, markPlayed: markPlayed)
    case .finished(let episode, let duration):
      updateEpisodePlayback(for: episode, position: duration, markPlayed: true)
    case .failed(let episode, let position, duration: _, error: _):
      updateEpisodePlayback(for: episode, position: position, markPlayed: false)
    }
  }

  private func updateEpisodePlayback(for episode: Episode, position: TimeInterval, markPlayed: Bool) {
    guard var storedEpisode = episodeLookup(episode.id) else { return }
    storedEpisode = storedEpisode.withPlaybackPosition(Int(position))
    if markPlayed && !storedEpisode.isPlayed {
      storedEpisode = storedEpisode.withPlayedStatus(true)
    }
    episodeUpdateHandler(storedEpisode)
  }
}

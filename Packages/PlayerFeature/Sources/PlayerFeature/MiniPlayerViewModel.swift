//
//  MiniPlayerViewModel.swift
//  PlayerFeature
//
//  Created for Issue 03.1.1.1: Mini-Player Foundation
//

import Combine
import CoreModels
import Foundation
import PlaybackEngine

/// View model for the mini-player that displays current playback state
@MainActor
public final class MiniPlayerViewModel: ObservableObject {
  // MARK: - Published Properties
  
  @Published public private(set) var currentEpisode: Episode?
  @Published public private(set) var isPlaying: Bool = false
  @Published public private(set) var isVisible: Bool = false
  @Published public private(set) var currentPosition: TimeInterval = 0
  @Published public private(set) var duration: TimeInterval = 0
  
  // MARK: - Private Properties
  
  private let playbackService: EpisodePlaybackService
  private var stateCancellable: AnyCancellable?
  
  // MARK: - Initialization
  
  public init(playbackService: EpisodePlaybackService) {
    self.playbackService = playbackService
    subscribeToPlaybackState()
  }
  
  // MARK: - Public Methods
  
  /// Toggle play/pause state
  public func togglePlayPause() {
    if isPlaying {
      playbackService.pause()
    } else {
      // Resume playback if we have a current episode
      if let episode = currentEpisode {
        playbackService.play(episode: episode, duration: duration > 0 ? duration : nil)
      }
    }
  }
  
  /// Skip forward by the configured interval (default 30s)
  public func skipForward() {
    // For now, this is a placeholder - full skip implementation will be in follow-up issues
    // The playback service interface would need to be extended to support seek operations
  }
  
  /// Skip backward by the configured interval (default 15s)
  public func skipBackward() {
    // For now, this is a placeholder - full skip implementation will be in follow-up issues
    // The playback service interface would need to be extended to support seek operations
  }
  
  // MARK: - Private Methods
  
  private func subscribeToPlaybackState() {
    stateCancellable = playbackService.statePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        self?.handlePlaybackStateChange(state)
      }
  }
  
  private func handlePlaybackStateChange(_ state: EpisodePlaybackState) {
    switch state {
    case .idle(let episode):
      currentEpisode = episode
      isPlaying = false
      isVisible = false
      currentPosition = 0
      duration = episode.duration ?? 0
      
    case .playing(let episode, let position, let dur):
      currentEpisode = episode
      isPlaying = true
      isVisible = true
      currentPosition = position
      duration = dur
      
    case .paused(let episode, let position, let dur):
      currentEpisode = episode
      isPlaying = false
      isVisible = true
      currentPosition = position
      duration = dur
      
    case .finished(let episode, let dur):
      currentEpisode = episode
      isPlaying = false
      isVisible = true
      currentPosition = dur
      duration = dur
    }
  }
}

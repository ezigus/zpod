//
//  MiniPlayerViewModel.swift
//  PlayerFeature
//
//  Created for Issue 03.1.1.1: Mini-Player Foundation
//

#if canImport(Combine)

import Combine
import CoreModels
import Foundation
import PlaybackEngine

public struct MiniPlayerDisplayState: Equatable, Sendable {
  public static let hidden = MiniPlayerDisplayState(
    isVisible: false,
    isPlaying: false,
    episode: nil,
    currentPosition: 0,
    duration: 0
  )

  public var isVisible: Bool
  public var isPlaying: Bool
  public var episode: Episode?
  public var currentPosition: TimeInterval
  public var duration: TimeInterval

  public init(
    isVisible: Bool,
    isPlaying: Bool,
    episode: Episode?,
    currentPosition: TimeInterval,
    duration: TimeInterval
  ) {
    self.isVisible = isVisible
    self.isPlaying = isPlaying
    self.episode = episode
    self.currentPosition = currentPosition
    self.duration = duration
  }
}

@MainActor
public final class MiniPlayerViewModel: ObservableObject {
  @Published public private(set) var displayState: MiniPlayerDisplayState = .hidden

  public var currentEpisode: Episode? { displayState.episode }
  public var isPlaying: Bool { displayState.isPlaying }
  public var isVisible: Bool { displayState.isVisible }
  public var currentPosition: TimeInterval { displayState.currentPosition }
  public var duration: TimeInterval { displayState.duration }

  private let playbackService: (EpisodePlaybackService & EpisodeTransportControlling)
  private let queueIsEmpty: () -> Bool
  private var stateCancellable: AnyCancellable?

  public init(
    playbackService: EpisodePlaybackService & EpisodeTransportControlling,
    queueIsEmpty: @escaping () -> Bool = { true }
  ) {
    self.playbackService = playbackService
    self.queueIsEmpty = queueIsEmpty
    subscribeToPlaybackState()
  }

  public func togglePlayPause() {
    if displayState.isPlaying {
      playbackService.pause()
      return
    }

    guard let episode = displayState.episode else { return }
    let resolvedDuration: TimeInterval?
    if displayState.duration > 0 {
      resolvedDuration = displayState.duration
    } else {
      resolvedDuration = episode.duration
    }

    playbackService.play(episode: episode, duration: resolvedDuration)

    if displayState.currentPosition > 0 {
      playbackService.seek(to: displayState.currentPosition)
    }
  }

  public func skipForward(interval: TimeInterval? = nil) {
    playbackService.skipForward(interval: interval)
  }

  public func skipBackward(interval: TimeInterval? = nil) {
    playbackService.skipBackward(interval: interval)
  }

  private func subscribeToPlaybackState() {
    stateCancellable = playbackService.statePublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] state in
        self?.handlePlaybackStateChange(state)
      }
  }

  private func handlePlaybackStateChange(_ state: EpisodePlaybackState) {
    switch state {
    case .idle:
      displayState = .hidden

    case .playing(let episode, let position, let duration):
      displayState = MiniPlayerDisplayState(
        isVisible: true,
        isPlaying: true,
        episode: episode,
        currentPosition: position,
        duration: duration
      )

    case .paused(let episode, let position, let duration):
      displayState = MiniPlayerDisplayState(
        isVisible: true,
        isPlaying: false,
        episode: episode,
        currentPosition: position,
        duration: duration
      )

    case .finished(let episode, let duration):
      if queueIsEmpty() {
        displayState = .hidden
      } else {
        displayState = MiniPlayerDisplayState(
          isVisible: true,
          isPlaying: false,
          episode: episode,
          currentPosition: duration,
          duration: duration
        )
      }
    }
  }
}

#else

import CoreModels
import Foundation
import PlaybackEngine

public struct MiniPlayerDisplayState: Equatable, Sendable {
  public static let hidden = MiniPlayerDisplayState(
    isVisible: false,
    isPlaying: false,
    episode: nil,
    currentPosition: 0,
    duration: 0
  )

  public var isVisible: Bool
  public var isPlaying: Bool
  public var episode: Episode?
  public var currentPosition: TimeInterval
  public var duration: TimeInterval

  public init(
    isVisible: Bool,
    isPlaying: Bool,
    episode: Episode?,
    currentPosition: TimeInterval,
    duration: TimeInterval
  ) {
    self.isVisible = isVisible
    self.isPlaying = isPlaying
    self.episode = episode
    self.currentPosition = currentPosition
    self.duration = duration
  }
}

public final class MiniPlayerViewModel {
  public private(set) var displayState: MiniPlayerDisplayState = .hidden
  private let queueIsEmpty: () -> Bool

  public init(
    playbackService: EpisodePlaybackService & EpisodeTransportControlling,
    queueIsEmpty: @escaping () -> Bool = { true }
  ) {
    self.queueIsEmpty = queueIsEmpty
  }

  public var currentEpisode: Episode? { displayState.episode }
  public var isPlaying: Bool { displayState.isPlaying }
  public var isVisible: Bool { displayState.isVisible }
  public var currentPosition: TimeInterval { displayState.currentPosition }
  public var duration: TimeInterval { displayState.duration }

  public func togglePlayPause() {}
  public func skipForward(interval: TimeInterval? = nil) {}
  public func skipBackward(interval: TimeInterval? = nil) {}
}

#endif

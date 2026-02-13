//
//  MiniPlayerViewModel.swift
//  PlayerFeature
//
//  Created for Issue 03.1.1.1: Mini-Player Foundation
//

import CombineSupport
import CoreModels
import Foundation
import PlaybackEngine
import SharedUtilities

// MARK: - Display State ------------------------------------------------------

public struct MiniPlayerDisplayState: Equatable, Sendable {
  public static let hidden = MiniPlayerDisplayState(
    isVisible: false,
    isPlaying: false,
    episode: nil,
    currentPosition: 0,
    duration: 0,
    error: nil
  )

  public var isVisible: Bool
  public var isPlaying: Bool
  public var episode: Episode?
  public var currentPosition: TimeInterval
  public var duration: TimeInterval
  public var error: PlaybackError?  // Issue 03.3.4.2: Expose error to view

  public init(
    isVisible: Bool,
    isPlaying: Bool,
    episode: Episode?,
    currentPosition: TimeInterval,
    duration: TimeInterval,
    error: PlaybackError? = nil
  ) {
    self.isVisible = isVisible
    self.isPlaying = isPlaying
    self.episode = episode
    self.currentPosition = currentPosition
    self.duration = duration
    self.error = error
  }
}

/// View model for the mini-player that exposes a compact summary of playback state.
@MainActor
public final class MiniPlayerViewModel: ObservableObject {
  // MARK: - Published State

  @Published public private(set) var displayState: MiniPlayerDisplayState = .hidden
  @Published public private(set) var playbackAlert: PlaybackAlertState?

  // MARK: - Convenience Accessors

  public var currentEpisode: Episode? { displayState.episode }
  public var isPlaying: Bool { displayState.isPlaying }
  public var isVisible: Bool { displayState.isVisible }
  public var currentPosition: TimeInterval { displayState.currentPosition }
  public var duration: TimeInterval { displayState.duration }

  // MARK: - Private Properties

  private let playbackService: (EpisodePlaybackService & EpisodeTransportControlling)
  private let queueIsEmpty: () -> Bool
  private let alertPresenter: PlaybackAlertPresenter
  private let hapticFeedback: HapticFeedbackServicing
  private var stateCancellable: AnyCancellable?
  private var alertCancellable: AnyCancellable?

  // MARK: - Initialization

  public init(
    playbackService: EpisodePlaybackService & EpisodeTransportControlling,
    queueIsEmpty: @escaping () -> Bool = { true },
    alertPresenter: PlaybackAlertPresenter = PlaybackAlertPresenter(),
    hapticFeedback: HapticFeedbackServicing = HapticFeedbackService.shared
  ) {
    self.playbackService = playbackService
    self.queueIsEmpty = queueIsEmpty
    self.alertPresenter = alertPresenter
    self.hapticFeedback = hapticFeedback
    subscribeToPlaybackState()
    subscribeToAlerts()
  }

  // MARK: - User Intents

  public func togglePlayPause() {
    hapticFeedback.impact(.light)
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
    hapticFeedback.impact(.light)
    playbackService.skipForward(interval: interval)
  }

  public func skipBackward(interval: TimeInterval? = nil) {
    hapticFeedback.impact(.light)
    playbackService.skipBackward(interval: interval)
  }

  public func dismissAlert() {
    alertPresenter.dismissAlert()
  }

  public func performPrimaryAlertAction() {
    alertPresenter.performPrimaryAction()
  }

  public func performSecondaryAlertAction() {
    alertPresenter.performSecondaryAction()
  }

  /// Issue 03.3.4.2: Retry playback for recoverable errors
  public func retryPlayback() {
    // Only retry if there's an error and an episode to retry
    guard displayState.error != nil,
          let episode = displayState.episode else { return }

    let position = displayState.currentPosition

    // Resolve duration (prefer display state, fallback to episode)
    let resolvedDuration: TimeInterval?
    if displayState.duration > 0 {
      resolvedDuration = displayState.duration
    } else {
      resolvedDuration = episode.duration
    }

    // Attempt playback again from the same position
    playbackService.play(episode: episode, duration: resolvedDuration)
    if position > 0 {
      playbackService.seek(to: position)
    }
  }

  // MARK: - Internal Helpers

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
        duration: duration,
        error: nil  // Issue 03.3.4.2: Clear error on successful playback
      )

    case .paused(let episode, let position, let duration):
      // Issue 03.3.4.2: Don't clear error on pause - errors persist until playback resumes
      // The PlaybackStateCoordinator pauses after errors, so clearing here would lose the error state
      let preservedError = displayState.error
      displayState = MiniPlayerDisplayState(
        isVisible: true,
        isPlaying: false,
        episode: episode,
        currentPosition: position,
        duration: duration,
        error: preservedError
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
          duration: duration,
          error: nil  // Issue 03.3.4.2: Clear error on finish
        )
      }
    case .failed(let episode, let position, let duration, let error):
      displayState = MiniPlayerDisplayState(
        isVisible: true,
        isPlaying: false,
        episode: episode,
        currentPosition: position,
        duration: duration,
        error: error  // Issue 03.3.4.2: Expose error to view
      )
    }
  }

  private func subscribeToAlerts() {
    alertCancellable = alertPresenter.$currentAlert
      .receive(on: RunLoop.main)
      .sink { [weak self] alert in
        self?.playbackAlert = alert
      }
  }
}

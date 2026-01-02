//
//  ExpandedPlayerViewModel.swift
//  PlayerFeature
//
//  Created for Issue 03.1.1.2: Expanded Player Layout & Interaction
//

import CombineSupport
import CoreModels
import Foundation
import OSLog
import PlaybackEngine
import SharedUtilities

/// View model for the full-screen expanded player interface.
@MainActor
public final class ExpandedPlayerViewModel: ObservableObject {
  // MARK: - Published State

  private static let logger = Logger(
    subsystem: "us.zig.zpod",
    category: "ExpandedPlayerViewModel"
  )

  @Published public private(set) var episode: Episode?
  @Published public private(set) var isPlaying: Bool = false
  @Published public private(set) var currentPosition: TimeInterval = 0
  @Published public private(set) var duration: TimeInterval = 0
  @Published public private(set) var isScrubbing: Bool = false
  @Published public private(set) var playbackAlert: PlaybackAlertState?

  // MARK: - Computed Properties

  public var progressFraction: Double {
    guard duration > 0 else { return 0 }
    return min(max(currentPosition / duration, 0), 1)
  }

  public var formattedCurrentTime: String {
    formatTime(currentPosition)
  }

  public var formattedDuration: String {
    formatTime(duration)
  }

  // MARK: - Private Properties

  private let playbackService: (EpisodePlaybackService & EpisodeTransportControlling)
  private let alertPresenter: PlaybackAlertPresenter
  private var stateCancellable: AnyCancellable?
  private var alertCancellable: AnyCancellable?

  // MARK: - Initialization

  public init(
    playbackService: EpisodePlaybackService & EpisodeTransportControlling,
    alertPresenter: PlaybackAlertPresenter = PlaybackAlertPresenter()
  ) {
    self.playbackService = playbackService
    self.alertPresenter = alertPresenter
    subscribeToPlaybackState()
    subscribeToAlerts()
  }

  // MARK: - User Intents

  public func togglePlayPause() {
    if isPlaying {
      playbackService.pause()
      return
    }

    guard let episode = episode else { return }
    let resolvedDuration = duration > 0 ? duration : episode.duration
    playbackService.play(episode: episode, duration: resolvedDuration)

    if currentPosition > 0 {
      playbackService.seek(to: currentPosition)
    }
  }

  public func skipForward(interval: TimeInterval? = nil) {
    playbackService.skipForward(interval: interval)
  }

  public func skipBackward(interval: TimeInterval? = nil) {
    playbackService.skipBackward(interval: interval)
  }

  public func beginScrubbing() {
    isScrubbing = true
  }

  public func updateScrubbingPosition(_ position: TimeInterval) {
    guard isScrubbing else { return }
    currentPosition = min(max(position, 0), duration)
  }

  public func endScrubbing() {
    guard isScrubbing else { return }
    isScrubbing = false
    playbackService.seek(to: currentPosition)
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

  // MARK: - Internal Helpers

  private func subscribeToPlaybackState() {
    stateCancellable = playbackService.statePublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] state in
        self?.handlePlaybackStateChange(state)
      }
  }

  private func handlePlaybackStateChange(_ state: EpisodePlaybackState) {
    // Don't update position while user is actively scrubbing
    guard !isScrubbing else { return }

    let previousPosition = currentPosition

    switch state {
    case .idle(let episode):
      self.episode = episode
      self.isPlaying = false
      self.currentPosition = 0
      self.duration = 0
      logPositionResetIfNeeded(previous: previousPosition, next: 0, state: "idle")

    case .playing(let episode, let position, let duration):
      self.episode = episode
      self.isPlaying = true
      self.currentPosition = position
      self.duration = duration
      logPositionResetIfNeeded(previous: previousPosition, next: position, state: "playing")

    case .paused(let episode, let position, let duration):
      self.episode = episode
      self.isPlaying = false
      self.currentPosition = position
      self.duration = duration
      logPositionResetIfNeeded(previous: previousPosition, next: position, state: "paused")

    case .finished(let episode, let duration):
      self.episode = episode
      self.isPlaying = false
      self.currentPosition = duration
      self.duration = duration
      logPositionResetIfNeeded(previous: previousPosition, next: duration, state: "finished")
    case .failed(let episode, let position, let duration, _):
      self.episode = episode
      self.isPlaying = false
      self.currentPosition = position
      self.duration = duration
      logPositionResetIfNeeded(previous: previousPosition, next: position, state: "failed")
    }
  }

  private var isPositionDebugEnabled: Bool {
    ProcessInfo.processInfo.environment["UITEST_POSITION_DEBUG"] == "1"
  }

  private func logPositionResetIfNeeded(
    previous: TimeInterval,
    next: TimeInterval,
    state: String
  ) {
    guard isPositionDebugEnabled else { return }
    guard previous > 5, next + 1 < previous else { return }
    Self.logger.info(
      "position jumped backward state=\(state, privacy: .public) previous=\(previous, privacy: .public) next=\(next, privacy: .public)"
    )
  }

  private func formatTime(_ interval: TimeInterval) -> String {
    let seconds = Int(interval)
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
      return String(format: "%d:%02d", minutes, secs)
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

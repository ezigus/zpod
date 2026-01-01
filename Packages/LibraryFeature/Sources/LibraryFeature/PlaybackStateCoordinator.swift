//
//  PlaybackStateCoordinator.swift
//  LibraryFeature
//
//  Created for Issue 03.1.1.3: Playback State Synchronization & Persistence
//  Manages shared playback state, persistence, and synchronization across app lifecycle
//

import CoreModels
import Foundation
import Persistence
import PlaybackEngine
import SharedUtilities

#if canImport(Combine)
  @preconcurrency import CombineSupport
#endif

#if canImport(UIKit)
  import UIKit
#endif

/// Coordinates playback state synchronization and persistence across the app
@MainActor
public final class PlaybackStateCoordinator {

  // MARK: - Properties

  private let playbackService: EpisodePlaybackService?
  private let settingsRepository: SettingsRepository
  private let episodeLookup: (String) async -> Episode?
  private let alertPresenter: PlaybackAlertPresenter?

  nonisolated(unsafe) private var stateCancellable: AnyCancellable?
  private var currentEpisode: Episode?
  private var currentPosition: TimeInterval = 0
  private var currentDuration: TimeInterval = 0
  private var isPlaying: Bool = false

  #if canImport(UIKit)
    nonisolated(unsafe) private var didEnterBackgroundObserver: NSObjectProtocol?
    nonisolated(unsafe) private var willEnterForegroundObserver: NSObjectProtocol?
  #endif

  // MARK: - Initialization

  public init(
    playbackService: EpisodePlaybackService?,
    settingsRepository: SettingsRepository,
    episodeLookup: @escaping (String) async -> Episode?,
    alertPresenter: PlaybackAlertPresenter? = nil
  ) {
    self.playbackService = playbackService
    self.settingsRepository = settingsRepository
    self.episodeLookup = episodeLookup
    self.alertPresenter = alertPresenter

    setupPlaybackObserver()
    setupLifecycleObservers()
  }

  deinit {
    cleanup()
  }

  // MARK: - Public Methods

  /// Attempt to restore playback from persisted state
  public func restorePlaybackIfNeeded() async {
    guard let resumeState = await settingsRepository.loadPlaybackResumeState() else {
      return
    }

    // Check if state is still valid (within 24 hours)
    guard resumeState.isValid else {
      await settingsRepository.clearPlaybackResumeState()
      presentAlert(for: .resumeStateExpired)
      return
    }

    // Look up the episode in the current library - do NOT use stored snapshot as fallback
    // This prevents stale/test data from persisting when the episode is no longer available
    guard let resolvedEpisode = await episodeLookup(resumeState.episodeId) else {
      await settingsRepository.clearPlaybackResumeState()
      // Don't show an alert for missing episodes - they may have been intentionally deleted
      return
    }

    // Restore the playback position
    currentEpisode = resolvedEpisode
    currentPosition = resumeState.position
    currentDuration = resumeState.duration
    isPlaying = false  // Don't auto-play on restore

    // Surface restored state to playback observers so UI reflects last session
    let restoredState = EpisodePlaybackState.paused(
      resolvedEpisode,
      position: resumeState.position,
      duration: resumeState.duration
    )

    if let injector = playbackService as? EpisodePlaybackStateInjecting {
      injector.injectPlaybackState(restoredState)
    }
  }

  /// Report an explicit playback error that should be surfaced to the user.
  public func reportPlaybackError(
    _ error: PlaybackError,
    retryAction: (() -> Void)? = nil
  ) {
    presentAlert(for: error, retryAction: retryAction)
  }

  /// Cleanup resources
  nonisolated public func cleanup() {
    stateCancellable?.cancel()
    stateCancellable = nil

    #if canImport(UIKit)
      if let observer = didEnterBackgroundObserver {
        NotificationCenter.default.removeObserver(observer)
        didEnterBackgroundObserver = nil
      }
      if let observer = willEnterForegroundObserver {
        NotificationCenter.default.removeObserver(observer)
        willEnterForegroundObserver = nil
      }
    #endif
  }

  // MARK: - Private Methods

  private func setupPlaybackObserver() {
    #if canImport(Combine)
      guard let playbackService = playbackService else { return }

      stateCancellable = playbackService.statePublisher
        .receive(on: RunLoop.main)
        .sink { [weak self] state in
          Task { @MainActor [weak self] in
            await self?.handlePlaybackStateChange(state)
          }
        }
    #endif
  }

  private func setupLifecycleObservers() {
    #if canImport(UIKit)
      // Save state when app goes to background
      didEnterBackgroundObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          await self?.persistCurrentState()
        }
      }

      // Optionally restore state when returning to foreground
      willEnterForegroundObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.willEnterForegroundNotification,
        object: nil,
        queue: .main
      ) { _ in
        Task { @MainActor in
          // State should already be current from background save
          // Just ensure sync is accurate
        }
      }
    #endif
  }

  private func handlePlaybackStateChange(_ state: EpisodePlaybackState) async {
    switch state {
    case .idle(let episode):
      currentEpisode = episode
      currentPosition = 0
      currentDuration = 0
      isPlaying = false

    case .playing(let episode, let position, let duration):
      currentEpisode = episode
      currentPosition = position
      currentDuration = duration
      isPlaying = true

    case .paused(let episode, let position, let duration):
      currentEpisode = episode
      currentPosition = position
      currentDuration = duration
      isPlaying = false
      // Persist state on pause
      await persistCurrentState()

    case .finished(let episode, let duration):
      currentEpisode = episode
      currentPosition = duration
      currentDuration = duration
      isPlaying = false
      // Clear resume state when finished
      await settingsRepository.clearPlaybackResumeState()
    case .failed(let episode, let position, let duration, let error):
      currentEpisode = episode
      currentPosition = position
      currentDuration = duration
      isPlaying = false
      await persistCurrentState()
      presentAlert(
        for: error,
        retryAction: makeRetryAction(for: episode, position: position, duration: duration)
      )
    }
  }

  private func persistCurrentState() async {
    guard let episode = currentEpisode else {
      return
    }

    // Don't persist if at the very beginning or very end
    guard currentPosition > 0 && currentPosition < currentDuration else {
      await settingsRepository.clearPlaybackResumeState()
      return
    }

    let resumeState = PlaybackResumeState(
      episodeId: episode.id,
      position: currentPosition,
      duration: currentDuration,
      timestamp: Date(),
      isPlaying: isPlaying,
      episode: episode
    )

    await settingsRepository.savePlaybackResumeState(resumeState)
  }

  private func presentAlert(
    for error: PlaybackError,
    retryAction: (() -> Void)? = nil
  ) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      playbackService?.pause()
      guard let presenter = alertPresenter else { return }
      let descriptor = error.descriptor()
      var action: PlaybackAlertAction?
      if let retryAction {
        action = PlaybackAlertAction(title: "Retry", handler: retryAction)
      }
      presenter.showAlert(descriptor, primaryAction: action)
    }
  }

  private func makeRetryAction(
    for episode: Episode,
    position: TimeInterval,
    duration: TimeInterval
  ) -> (() -> Void)? {
    guard let service = playbackService else { return nil }
    let transport = service as? EpisodeTransportControlling

    return { [weak self] in
      Task { @MainActor in
        guard self != nil else { return }
        service.play(episode: episode, duration: duration)
        if position > 0 {
          transport?.seek(to: position)
        }
      }
    }
  }
}

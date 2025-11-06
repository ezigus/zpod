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

  nonisolated private var stateCancellable: AnyCancellable?
  private var currentEpisode: Episode?
  private var currentPosition: TimeInterval = 0
  private var currentDuration: TimeInterval = 0
  private var isPlaying: Bool = false

  #if canImport(UIKit)
    nonisolated private var didEnterBackgroundObserver: NSObjectProtocol?
    nonisolated private var willEnterForegroundObserver: NSObjectProtocol?
  #endif

  // MARK: - Initialization

  public init(
    playbackService: EpisodePlaybackService?,
    settingsRepository: SettingsRepository,
    episodeLookup: @escaping (String) async -> Episode?
  ) {
    self.playbackService = playbackService
    self.settingsRepository = settingsRepository
    self.episodeLookup = episodeLookup

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
      return
    }

    // Look up the episode
    guard let episode = await episodeLookup(resumeState.episodeId) else {
      // Episode no longer exists, clear state
      await settingsRepository.clearPlaybackResumeState()
      return
    }

    // Restore the playback position
    currentEpisode = episode
    currentPosition = resumeState.position
    currentDuration = resumeState.duration
    isPlaying = false  // Don't auto-play on restore

    // If we should resume playing, do so
    if resumeState.isPlaying {
      playbackService?.play(episode: episode, duration: resumeState.duration)
      if let transportControl = playbackService as? EpisodeTransportControlling {
        transportControl.seek(to: resumeState.position)
      }
    }
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

  nonisolated private func setupPlaybackObserver() {
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

  nonisolated private func setupLifecycleObservers() {
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
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
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
      isPlaying: isPlaying
    )

    await settingsRepository.savePlaybackResumeState(resumeState)
  }
}

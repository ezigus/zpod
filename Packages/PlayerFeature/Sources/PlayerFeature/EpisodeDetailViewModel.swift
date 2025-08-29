@preconcurrency import Combine
import Foundation
import CoreModels
import PlaybackEngine

/// ViewModel for Episode Detail view, coordinates with EpisodePlaybackService
@MainActor
public class EpisodeDetailViewModel: ObservableObject {
  @Published public var episode: Episode?
  @Published public var isPlaying = false
  @Published public var currentPosition: TimeInterval = 0
  @Published public var progressFraction: Double = 0
  @Published public var formattedCurrentTime = "0:00"
  @Published public var formattedDuration = "0:00"
  @Published public var playbackSpeed: Float = 1.0
  @Published public var chapters: [Chapter] = []
  @Published public var currentChapter: Chapter?

  private let playbackService: EpisodePlaybackService
  private let sleepTimer: SleepTimer
  private var cancellables = Set<AnyCancellable>()
  private var currentState: EpisodePlaybackState?

  // Enhanced player reference for extended features
  private var enhancedPlayer: EnhancedEpisodePlayer? {
    return playbackService as? EnhancedEpisodePlayer
  }

  public init(
    playbackService: EpisodePlaybackService? = nil,
    sleepTimer: SleepTimer? = nil
  ) {
    // Use provided service or create enhanced player (fallback to stub for compatibility)
    self.playbackService = playbackService ?? EnhancedEpisodePlayer()
    // Create SleepTimer on MainActor to avoid Swift 6 concurrency violation
    if let providedTimer = sleepTimer {
      self.sleepTimer = providedTimer
    } else {
      self.sleepTimer = SleepTimer()
    }
    observePlaybackState()
  }

  public func loadEpisode(_ episode: Episode) {
    self.episode = episode
    // Episode currently has no chapters property; set empty and await parsing support
    self.chapters = []
    updateCurrentChapter()
    updatePlaybackSpeed()
    // Reset UI state when loading a new episode
    updateUIFromCurrentState()
  }

  public func playPause() {
    guard let episode = episode else { return }

    if isPlaying {
      playbackService.pause()
    } else {
      // Use episode's duration or a default
      let duration = episode.duration ?? 300.0  // 5 minutes default
      playbackService.play(episode: episode, duration: duration)
    }
  }

  // MARK: - Enhanced Controls

  public func skipForward() {
    enhancedPlayer?.skipForward()
  }

  public func skipBackward() {
    enhancedPlayer?.skipBackward()
  }

  public func seek(to position: TimeInterval) {
    enhancedPlayer?.seek(to: position)
  }

  public func setPlaybackSpeed(_ speed: Float) {
    enhancedPlayer?.setPlaybackSpeed(speed)
    self.playbackSpeed = speed
  }

  public func jumpToChapter(_ chapter: Chapter) {
    enhancedPlayer?.jumpToChapter(chapter)
  }

  public func markAsPlayed(_ played: Bool) {
    enhancedPlayer?.markEpisodeAs(played: played)
  }

  // MARK: - Sleep Timer

  public func startSleepTimer(duration: TimeInterval) {
    sleepTimer.start(duration: duration)
  }

  public func stopSleepTimer() {
    sleepTimer.stop()
  }

  public func resetSleepTimer() {
    sleepTimer.reset()
  }

  public var sleepTimerActive: Bool {
    sleepTimer.isActive
  }

  public var sleepTimerRemainingTime: TimeInterval {
    sleepTimer.remainingTime
  }

  private func observePlaybackState() {
    playbackService.statePublisher
      .sink { [weak self] state in
        Task { @MainActor in
          self?.currentState = state
          self?.updateUI(for: state)
        }
      }
      .store(in: &cancellables)
  }

  private func updateUIFromCurrentState() {
    if let state = currentState {
      updateUI(for: state)
    }
  }

  private func updateUI(for state: EpisodePlaybackState) {
    switch state {
    case .idle(_):
      isPlaying = false
      currentPosition = 0
      progressFraction = 0
      formattedCurrentTime = "0:00"
      formattedDuration = "0:00"

    case .playing(_, let position, let duration):
      isPlaying = true
      currentPosition = position
      updateProgress(position: position, duration: duration)

    case .paused(_, let position, let duration):
      isPlaying = false
      currentPosition = position
      updateProgress(position: position, duration: duration)

    case .finished(_, let duration):
      isPlaying = false
      currentPosition = duration
      updateProgress(position: duration, duration: duration)
    }

    updateCurrentChapter()
  }

  private func updateProgress(position: TimeInterval, duration: TimeInterval) {
    progressFraction = duration > 0 ? min(max(position / duration, 0), 1) : 0
    formattedCurrentTime = formatTime(position)
    formattedDuration = formatTime(duration)
  }

  private func updateCurrentChapter() {
    guard !chapters.isEmpty else {
      currentChapter = nil
      return
    }

    // Find the current chapter based on position
    currentChapter = chapters.last { chapter in
      chapter.startTime <= currentPosition
    }
  }

  private func updatePlaybackSpeed() {
    if let player = enhancedPlayer {
      playbackSpeed = player.getCurrentPlaybackSpeed()
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    let remainingSeconds = Int(seconds) % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
  }
}
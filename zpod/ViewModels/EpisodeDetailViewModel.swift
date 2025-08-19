@preconcurrency import Combine
import Foundation

/// ViewModel for Episode Detail view, coordinates with EpisodePlaybackService
@MainActor
class EpisodeDetailViewModel: ObservableObject {
  @Published var episode: Episode?
  @Published var isPlaying = false
  @Published var currentPosition: TimeInterval = 0
  @Published var progressFraction: Double = 0
  @Published var formattedCurrentTime = "0:00"
  @Published var formattedDuration = "0:00"
  @Published var playbackSpeed: Float = 1.0
  @Published var chapters: [Chapter] = []
  @Published var currentChapter: Chapter?

  private let playbackService: EpisodePlaybackService
  private let sleepTimer: SleepTimer
  private var cancellables = Set<AnyCancellable>()
  private var currentState: EpisodePlaybackState?

  // Enhanced player reference for extended features
  private var enhancedPlayer: EnhancedEpisodePlayer? {
    return playbackService as? EnhancedEpisodePlayer
  }

  init(
    playbackService: EpisodePlaybackService? = nil,
    sleepTimer: SleepTimer? = nil
  ) {
    // Use provided service or create enhanced player (fallback to stub for compatibility)
    self.playbackService = playbackService ?? EnhancedEpisodePlayer()
    // Avoid calling a @MainActor initializer in a default argument context (Swift 6 strict concurrency)
    self.sleepTimer = sleepTimer ?? SleepTimer()
    observePlaybackState()
  }

  func loadEpisode(_ episode: Episode) {
    self.episode = episode
    self.chapters = episode.chapters
    updateCurrentChapter()
    updatePlaybackSpeed()
    // Reset UI state when loading a new episode
    updateUIFromCurrentState()
  }

  func playPause() {
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

  func skipForward() {
    enhancedPlayer?.skipForward()
  }

  func skipBackward() {
    enhancedPlayer?.skipBackward()
  }

  func seek(to position: TimeInterval) {
    enhancedPlayer?.seek(to: position)
  }

  func setPlaybackSpeed(_ speed: Float) {
    enhancedPlayer?.setPlaybackSpeed(speed)
    self.playbackSpeed = speed
  }

  func jumpToChapter(_ chapter: Chapter) {
    enhancedPlayer?.jumpToChapter(chapter)
  }

  func markAsPlayed(_ played: Bool) {
    enhancedPlayer?.markEpisodeAs(played: played)
  }

  // MARK: - Sleep Timer

  func startSleepTimer(duration: TimeInterval) {
    sleepTimer.start(duration: duration)
  }

  func stopSleepTimer() {
    sleepTimer.stop()
  }

  func resetSleepTimer() {
    sleepTimer.reset()
  }

  var sleepTimerActive: Bool {
    sleepTimer.isActive
  }

  var sleepTimerRemainingTime: TimeInterval {
    sleepTimer.remainingTime
  }

  private func observePlaybackState() {
    playbackService.statePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        self?.currentState = state
        self?.updateUI(for: state)
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

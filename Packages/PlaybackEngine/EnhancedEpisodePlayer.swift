#if canImport(Combine)
@preconcurrency import Combine
#endif
import Foundation

/// Enhanced playback service with advanced controls for Issue 03
@MainActor
public final class EnhancedEpisodePlayer: EpisodePlaybackService, ObservableObject {

  // MARK: - EpisodePlaybackService Protocol

  public var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  // MARK: - Properties

  private let stateSubject: CurrentValueSubject<EpisodePlaybackState, Never>
  private let ticker: Ticker
  private let settings: PlaybackSettings
  private let sleepTimer: SleepTimer
  private let chapterParser: ChapterParser
  private let episodeStateManager: EpisodeStateManager

  // Playback state
  private var currentEpisode: Episode?
  private var episodeDuration: TimeInterval = 0
  private var currentPosition: TimeInterval = 0
  private var isPlaying = false
  private var playbackSpeed: Float = 1.0
  private var isSpeedExplicitlySet = false  // Track if speed was explicitly set
  private var generation = 0

  // Cancellables
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Initialization

  public init(
    ticker: Ticker = TimerTicker(),
    settings: PlaybackSettings = PlaybackSettings(),
    sleepTimer: SleepTimer? = nil,
    chapterParser: ChapterParser = BasicChapterParser(),
    episodeStateManager: EpisodeStateManager? = nil
  ) {
    self.ticker = ticker
    self.settings = settings
    // Avoid calling a @MainActor initializer in a default argument context (Swift 6 strict concurrency)
    self.sleepTimer = sleepTimer ?? SleepTimer()
    self.chapterParser = chapterParser
    // Avoid calling a @MainActor initializer in a default argument context (Swift 6 strict concurrency)
    self.episodeStateManager = episodeStateManager ?? InMemoryEpisodeStateManager()

    // Initialize state
    let initialEpisode = Episode(id: "initial", title: "No Episode")
    self.stateSubject = CurrentValueSubject(.idle(initialEpisode))

    setupSleepTimer()
  }

  deinit {
    ticker.cancel()
  }

  // MARK: - EpisodePlaybackService Implementation

  public func play(episode: Episode, duration: TimeInterval? = nil) {
    let isNewEpisode = currentEpisode?.id != episode.id

    if isNewEpisode {
      // Save current episode position before switching
      if let currentEp = currentEpisode {
        let stateManager = episodeStateManager
        let position = currentPosition
        Task {
          await stateManager.updatePlaybackPosition(currentEp, position: position)
        }
      }
      
      // Stop current episode if any
      isPlaying = false
      ticker.cancel()
      
      currentEpisode = episode
      episodeDuration = duration ?? episode.duration ?? 300

      // Apply intro skip if configured
      let introSkip = settings.introSkipDuration(for: episode.podcastId ?? "")
      currentPosition = max(introSkip, episode.playbackPosition)

      // Set playback speed for this episode - only if not explicitly set
      if !isSpeedExplicitlySet {
        playbackSpeed = getCurrentPlaybackSpeed()
      }
    }

    isPlaying = true
    generation += 1

    emitCurrentPlayingState()
    startTicker()
    
    // Update position asynchronously
    let stateManager = episodeStateManager
    let position = currentPosition
    Task {
      await updateEpisodePosition(position, using: stateManager)
    }
  }

  public func pause() {
    guard let episode = currentEpisode else { return }

    isPlaying = false
    ticker.cancel()

    emitState(.paused(episode, position: currentPosition, duration: episodeDuration))
    
    // Update position asynchronously
    let stateManager = episodeStateManager
    let position = currentPosition
    Task {
      await updateEpisodePosition(position, using: stateManager)
    }
  }

  // MARK: - Extended Controls

  /// Seek to a specific time position
  public func seek(to time: TimeInterval) {
    guard let episode = currentEpisode else { return }

    let clampedTime = max(0, min(time, episodeDuration))
    currentPosition = clampedTime

    let stateManager = episodeStateManager
    Task {
      await updateEpisodePosition(clampedTime, using: stateManager)
      
      // Check if seeking past played threshold should auto-mark as played
      await checkAutoMarkAsPlayed(episode: episode, position: clampedTime, using: stateManager)
    }
    emitCurrentPlayingState()
  }

  /// Skip forward by the configured interval
  public func skipForward() {
    let newTime = currentPosition + settings.skipForwardInterval
    seek(to: newTime)
  }

  /// Skip backward by the configured interval
  public func skipBackward() {
    let newTime = currentPosition - settings.skipBackwardInterval
    seek(to: newTime)
  }

  /// Set playback speed
  public func setPlaybackSpeed(_ speed: Float) {
    playbackSpeed = max(0.8, min(5.0, speed))
    isSpeedExplicitlySet = true
  }

  /// Get current playback speed
  public func getCurrentPlaybackSpeed() -> Float {
    // If playback speed has been explicitly set, return the set speed
    if isSpeedExplicitlySet {
      return playbackSpeed
    }
    
    // Otherwise fall back to podcast/global settings
    guard let episode = currentEpisode, let podcastId = episode.podcastId else {
      return settings.globalPlaybackSpeed
    }
    return settings.playbackSpeed(for: podcastId)
  }

  /// Jump to a specific chapter
  public func jumpToChapter(_ chapter: Chapter) {
    seek(to: chapter.startTime)
  }

  /// Mark current episode as played/unplayed
  public func markEpisodeAs(played: Bool) {
    guard let episode = currentEpisode else { return }
    let stateManager = episodeStateManager
    Task {
      await stateManager.setPlayedStatus(episode, isPlayed: played)
    }
  }

  // MARK: - Private Implementation

  private func startTicker() {
    let localGeneration = generation
    ticker.schedule(every: 1.0) { [weak self] in
      Task { @MainActor in
        await self?.handleTick(expectedGeneration: localGeneration)
      }
    }
  }

  private func handleTick(expectedGeneration: Int) async {
    guard isPlaying,
      expectedGeneration == generation,
      let episode = currentEpisode
    else { return }

    // FIXED: Advance position based on current playback speed
    currentPosition += Double(getCurrentPlaybackSpeed())

    // Check for outro skip
    let outroSkip = settings.outroSkipDuration(for: episode.podcastId ?? "")
    let effectiveEndTime = episodeDuration - outroSkip

    if currentPosition >= effectiveEndTime {
      await handlePlaybackEnd()
      return
    }

    // Update position and emit state
    let stateManager = episodeStateManager
    await updateEpisodePosition(currentPosition, using: stateManager)
    
    // Check if progressing past played threshold should auto-mark as played
    await checkAutoMarkAsPlayed(episode: episode, position: currentPosition, using: stateManager)
    
    emitCurrentPlayingState()
  }

  // FIXED: Complete implementation of handlePlaybackEnd
  private func handlePlaybackEnd() async {
    guard let episode = currentEpisode else { return }

    isPlaying = false
    ticker.cancel()

    // Check for outro skip to determine final position
    let outroSkip = settings.outroSkipDuration(for: episode.podcastId ?? "")
    let finalPosition = episodeDuration - outroSkip

    // Mark as played if auto-marking is enabled
    let stateManager = episodeStateManager
    if settings.autoMarkAsPlayed {
      await stateManager.setPlayedStatus(episode, isPlayed: true)
    }

    // Update final position (accounting for outro skip)
    await updateEpisodePosition(finalPosition, using: stateManager)
    
    // Emit finished state
    emitState(.finished(episode, duration: episodeDuration))
  }

  private func updateEpisodePosition(_ position: TimeInterval, using stateManager: EpisodeStateManager) async {
    guard let episode = currentEpisode else { return }
    await stateManager.updatePlaybackPosition(episode, position: position)
  }

  private func checkAutoMarkAsPlayed(episode: Episode, position: TimeInterval, using stateManager: EpisodeStateManager) async {
    guard settings.autoMarkAsPlayed,
          episodeDuration > 0 else { return }
    
    // Get current episode state to check if already marked as played
    let currentEpisodeState = await stateManager.getEpisodeState(episode)
    guard !currentEpisodeState.isPlayed else { return }
    
    let progress = position / episodeDuration
    if progress >= Double(settings.playedThreshold) {
      await stateManager.setPlayedStatus(episode, isPlayed: true)
    }
  }

  private func emitCurrentPlayingState() {
    guard let episode = currentEpisode else { return }
    emitState(.playing(episode, position: currentPosition, duration: episodeDuration))
  }

  private func emitState(_ state: EpisodePlaybackState) {
    stateSubject.send(state)
  }

  private func setupSleepTimer() {
    // Set up sleep timer callback to pause playback when timer expires
    sleepTimer.onTimerExpired = { [weak self] in
      Task { @MainActor in
        self?.pause()
      }
    }
  }
}

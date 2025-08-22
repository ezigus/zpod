#if canImport(Combine)
@preconcurrency import Combine
#endif
import Foundation
import AVFoundation

#if canImport(MediaPlayer)
  import MediaPlayer
#endif

/// AVFoundation-based implementation of EpisodePlaybackService
@MainActor
public final class AVFoundationAudioPlayer: NSObject, EpisodePlaybackService, ObservableObject {

  // MARK: - EpisodePlaybackService Protocol

  public var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  // MARK: - Private Properties

  private let stateSubject: CurrentValueSubject<EpisodePlaybackState, Never>

  #if canImport(AVFoundation)
    private let player: AVPlayer
    private var timeObserver: Any?
  #endif

  private var currentEpisode: Episode?
  private var episodeDuration: TimeInterval = 0
  private var generation = 0
  private var isPlaying = false
  private var currentPosition: TimeInterval = 0

  // Settings and services
  private let settings: PlaybackSettings
  private let sleepTimer: SleepTimer
  private let chapterParser: ChapterParser

  // Episode state tracking
  private var episodeStateManager: EpisodeStateManager

  // Cancellables for Combine subscriptions
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Initialization

  public init(
    settings: PlaybackSettings = PlaybackSettings(),
    sleepTimer: SleepTimer = SleepTimer(),
    chapterParser: ChapterParser = BasicChapterParser(),
    episodeStateManager: EpisodeStateManager? = nil
  ) {
    self.settings = settings
    self.sleepTimer = sleepTimer
    self.chapterParser = chapterParser
    // Avoid invoking a @MainActor initializer inside a default argument (Swift 6 strict concurrency)
    self.episodeStateManager = episodeStateManager ?? InMemoryEpisodeStateManager()

    #if canImport(AVFoundation)
      // Initialize player on supported platforms
      self.player = AVPlayer()
    #endif

    // Initialize state with idle
    let initialEpisode = Episode(id: "initial", title: "No Episode")
    self.stateSubject = CurrentValueSubject(.idle(initialEpisode))

    super.init()

    #if canImport(AVFoundation)
      setupAudioSession()
      setupPlayerObservers()
    #endif

    setupSleepTimer()

    #if canImport(MediaPlayer)
      setupRemoteCommandCenter()
    #endif
  }

  deinit {
    teardown()
  }

  // MARK: - EpisodePlaybackService Implementation

  public func play(episode: Episode, duration: TimeInterval? = nil) {
    Task { @MainActor in
      await playEpisode(episode, duration: duration)
    }
  }

  public func pause() {
    Task { @MainActor in
      await pausePlayback()
    }
  }

  // MARK: - Extended Playback Controls

  /// Seek to a specific time position
  public func seek(to time: TimeInterval) {
    guard currentEpisode != nil else { return }

    let clampedTime = max(0, min(time, episodeDuration))

    #if canImport(AVFoundation)
      let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

      player.seek(to: cmTime) { [weak self] completed in
        guard completed, let self = self else { return }
        Task { @MainActor in
          await self.updateEpisodePosition(clampedTime)
          self.emitCurrentState()
        }
      }
    #else
      // Fallback for non-AVFoundation platforms
      currentPosition = clampedTime
      Task {
        await updateEpisodePosition(clampedTime)
        emitCurrentState()
      }
    #endif
  }

  /// Skip forward by the configured interval
  public func skipForward() {
    guard currentEpisode != nil else { return }
    let currentTime = player.currentTime().seconds
    let newTime = currentTime + settings.skipForwardInterval
    seek(to: newTime)
  }

  /// Skip backward by the configured interval
  public func skipBackward() {
    guard currentEpisode != nil else { return }
    let currentTime = player.currentTime().seconds
    let newTime = currentTime - settings.skipBackwardInterval
    seek(to: newTime)
  }

  /// Set playback speed
  public func setPlaybackSpeed(_ speed: Float) {
    let clampedSpeed = max(0.8, min(5.0, speed))
    player.rate = player.timeControlStatus == .playing ? clampedSpeed : 0

    // Store speed setting if we have a current episode with podcast context
    if let episode = currentEpisode, episode.podcastId != nil {
      // Note: In a full implementation, this would update persisted settings
      // For now, we just update the player rate
    }
  }

  /// Get current playback speed
  public func getCurrentPlaybackSpeed() -> Float {
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
    Task {
      await episodeStateManager.setPlayedStatus(episode, isPlayed: played)
    }
  }

  // MARK: - Private Implementation

  private func playEpisode(_ episode: Episode, duration: TimeInterval?) async {
    // Handle episode switching or resuming
    let isNewEpisode = currentEpisode?.id != episode.id

    if isNewEpisode {
      await stopCurrentEpisode()
      currentEpisode = episode
      episodeDuration = duration ?? episode.duration ?? 300  // Default 5 minutes

      // Apply intro skip if configured
      let introSkip = settings.introSkipDuration(for: episode.podcastId ?? "")
      let startPosition = max(introSkip, episode.playbackPosition)

      // Load new media if we have a URL
      if let mediaURL = episode.mediaURL {
        await loadMedia(url: mediaURL, startPosition: startPosition)
      } else {
        // No media URL - emit playing state but won't actually play audio
        emitState(.playing(episode, position: startPosition, duration: episodeDuration))
      }
    } else {
      // Same episode - just resume
      resumePlayback()
    }

    generation += 1
    startTimeObserver()
  }

  private func pausePlayback() async {
    guard let episode = currentEpisode else { return }

    player.pause()
    stopTimeObserver()

    let currentPosition = player.currentTime().seconds
    await updateEpisodePosition(currentPosition)

    emitState(.paused(episode, position: currentPosition, duration: episodeDuration))
  }

  private func resumePlayback() {
    guard let episode = currentEpisode else { return }

    let speed = getCurrentPlaybackSpeed()
    player.rate = speed

    let currentPosition = player.currentTime().seconds
    emitState(.playing(episode, position: currentPosition, duration: episodeDuration))
  }

  private func stopCurrentEpisode() async {
    player.pause()
    stopTimeObserver()

    if currentEpisode != nil {
      let currentPosition = player.currentTime().seconds
      await updateEpisodePosition(currentPosition)
    }
  }

  private func loadMedia(url: URL, startPosition: TimeInterval) async {
    let playerItem = AVPlayerItem(url: url)
    player.replaceCurrentItem(with: playerItem)

    // Wait for item to be ready
    await waitForPlayerItemReady(playerItem)

    // Seek to start position if needed
    if startPosition > 0 {
      let cmTime = CMTime(seconds: startPosition, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
      await player.seek(to: cmTime)
    }

    // Start playback
    let speed = getCurrentPlaybackSpeed()
    player.rate = speed

    if let episode = currentEpisode {
      emitState(.playing(episode, position: startPosition, duration: episodeDuration))
    }
  }

  private func waitForPlayerItemReady(_ item: AVPlayerItem) async {
    // Simple wait for ready status - in production might use KVO
    for _ in 0..<50 {  // Max 5 second wait
      if item.status == .readyToPlay { return }
      try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
    }
  }

  private func emitCurrentState() {
    guard let episode = currentEpisode else { return }

    let currentPosition = player.currentTime().seconds

    switch player.timeControlStatus {
    case .playing:
      emitState(.playing(episode, position: currentPosition, duration: episodeDuration))
    case .paused:
      emitState(.paused(episode, position: currentPosition, duration: episodeDuration))
    case .waitingToPlayAtSpecifiedRate:
      emitState(.playing(episode, position: currentPosition, duration: episodeDuration))
    @unknown default:
      emitState(.idle(episode))
    }
  }

  private func emitState(_ state: EpisodePlaybackState) {
    stateSubject.send(state)
  }

  // MARK: - Audio Session Setup

  private func setupAudioSession() {
    #if os(iOS) || os(watchOS) || os(tvOS)
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .default, options: [])
      try audioSession.setActive(true)
    } catch {
      print("Failed to setup audio session: \(error)")
    }
    #endif
    // On macOS, AVAudioSession is not available and not needed
  }

  // MARK: - Player Observers

  private func setupPlayerObservers() {
    // Observe playback end
    NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
      .sink { [weak self] _ in
        Task { @MainActor in
          await self?.handlePlaybackEnd()
        }
      }
      .store(in: &cancellables)
  }

  private func handlePlaybackEnd() async {
    guard let episode = currentEpisode else { return }

    stopTimeObserver()

    // Check for outro skip
    let outroSkip = settings.outroSkipDuration(for: episode.podcastId ?? "")
    let finalPosition = episodeDuration - outroSkip

    // Mark as played if auto-marking is enabled
    if settings.autoMarkAsPlayed {
      await episodeStateManager.setPlayedStatus(episode, isPlayed: true)
    }

    // Update final position
    await updateEpisodePosition(finalPosition)

    emitState(.finished(episode, duration: episodeDuration))
  }

  // MARK: - Time Observer

  private func startTimeObserver() {
    stopTimeObserver()

    let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      Task { @MainActor in
        await self?.handleTimeUpdate(time)
      }
    }
  }

  private func stopTimeObserver() {
    if let observer = timeObserver {
      player.removeTimeObserver(observer)
      timeObserver = nil
    }
  }

  private func handleTimeUpdate(_ time: CMTime) async {
    guard let episode = currentEpisode else { return }

    let currentPosition = time.seconds

    // Check if we've reached the end (accounting for outro skip)
    let outroSkip = settings.outroSkipDuration(for: episode.podcastId ?? "")
    let effectiveEndTime = episodeDuration - outroSkip

    if currentPosition >= effectiveEndTime {
      await handlePlaybackEnd()
      return
    }

    // Update position
    await updateEpisodePosition(currentPosition)

    // Emit current state
    if player.timeControlStatus == .playing {
      emitState(.playing(episode, position: currentPosition, duration: episodeDuration))
    }
  }

  // MARK: - Episode State Management

  private func updateEpisodePosition(_ position: TimeInterval) async {
    guard let episode = currentEpisode else { return }
    await episodeStateManager.updatePlaybackPosition(episode, position: position)
  }

  // MARK: - Sleep Timer

  private func setupSleepTimer() {
    sleepTimer.onTimerExpired = { [weak self] in
      Task { @MainActor in
        await self?.pausePlayback()
      }
    }
  }

  // MARK: - Remote Command Center (for lock screen controls)

  private func setupRemoteCommandCenter() {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.addTarget { [weak self] _ in
      Task { @MainActor in
        if let episode = self?.currentEpisode {
          await self?.playEpisode(episode, duration: self?.episodeDuration)
        }
      }
      return .success
    }

    commandCenter.pauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in
        await self?.pausePlayback()
      }
      return .success
    }

    commandCenter.skipForwardCommand.addTarget { [weak self] _ in
      self?.skipForward()
      return .success
    }

    commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
      self?.skipBackward()
      return .success
    }
  }

  // MARK: - Cleanup

  nonisolated private func teardown() {
    Task { @MainActor in
      stopTimeObserver()
      player.pause()
      player.replaceCurrentItem(with: nil)
    }

    // Cleanup remote command center
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.playCommand.removeTarget(self)
    commandCenter.pauseCommand.removeTarget(self)
    commandCenter.skipForwardCommand.removeTarget(self)
    commandCenter.skipBackwardCommand.removeTarget(self)
  }
}

import CoreModels
@preconcurrency import Foundation
import OSLog
import SharedUtilities

#if canImport(Combine)
  @preconcurrency import CombineSupport
#endif

public struct AudioDebugInfo: Equatable, Sendable {
  public let playbackMode: String
  public let audioURL: String
  public let audioURLAccess: String
  public let engineStatus: String
  public let engineRate: String
  public let engineError: String
  public let engineIsPlaying: Bool
  public let playerIsPlaying: Bool
  public let position: TimeInterval
  public let duration: TimeInterval

  public init(
    playbackMode: String,
    audioURL: String,
    audioURLAccess: String,
    engineStatus: String,
    engineRate: String,
    engineError: String,
    engineIsPlaying: Bool,
    playerIsPlaying: Bool,
    position: TimeInterval,
    duration: TimeInterval
  ) {
    self.playbackMode = playbackMode
    self.audioURL = audioURL
    self.audioURLAccess = audioURLAccess
    self.engineStatus = engineStatus
    self.engineRate = engineRate
    self.engineError = engineError
    self.engineIsPlaying = engineIsPlaying
    self.playerIsPlaying = playerIsPlaying
    self.position = position
    self.duration = duration
  }
}

/// Enhanced playback engine that powers advanced controls for the episode detail surface and
/// player-focused integration tests.
@MainActor
public final class EnhancedEpisodePlayer: EpisodePlaybackService, EpisodeTransportControlling {
  private enum Constants {
    static let placeholderEpisode = Episode(id: "enhanced-placeholder", title: "Episode")
    static let finishTolerance: TimeInterval = 1.0
    static let chapterPositionTolerance: TimeInterval = 0.5
    static let minimumAutoChapterDuration: TimeInterval = 600
    static let minimumChapterSegment: TimeInterval = 90
    static let defaultDuration: TimeInterval = 300
    static let tickInterval: TimeInterval = 0.5
    static let minimumSpeed: Float = 0.8
    static let maximumSpeed: Float = 5.0
    static let persistenceInterval: TimeInterval = 5.0  // Persist every 5 seconds
  }

  @MainActor
  private static let logger = Logger(
    subsystem: "us.zig.zpod",
    category: "EnhancedEpisodePlayer"
  )

  private let episodeStateManager: EpisodeStateManager
  private let playbackSettings: PlaybackSettings
  private let chapterResolver: ((Episode, TimeInterval) -> [Chapter])?

  private(set) var currentEpisode: Episode?
  private(set) var currentDuration: TimeInterval = 0
  public private(set) var currentPosition: TimeInterval = 0
  public private(set) var playbackSpeed: Float
  public private(set) var isSkipSilenceEnabled = false
  public private(set) var isVolumeBoostEnabled = false
  public private(set) var isPlaying = false

  private var chapters: [Chapter] = []
  private var currentChapterIndex: Int?
  private let tickerFactory: () -> Ticker
  private var activeTicker: Ticker?
  private var lastPersistenceTime: TimeInterval = 0
  
  #if os(iOS)
  private let audioEngine: AVPlayerPlaybackEngine?
  #endif

  #if canImport(Combine)
    private let stateSubject: CurrentValueSubject<EpisodePlaybackState, Never>
    public var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
      stateSubject.eraseToAnyPublisher()
    }
  #endif

  /// Create an enhanced episode player.
  /// - Parameters:
  ///   - playbackSettings: Source for skip intervals and default playback speed.
  ///   - stateManager: Persists playback position and played state; defaults to in-memory storage.
  ///   - chapterResolver: Optional override to provide chapters for an episode.
  ///   - ticker: Optional ticker for deterministic testing; defaults to TimerTicker for production.
  ///   - audioEngine: Optional AVPlayerPlaybackEngine for actual audio playback (iOS only).
  ///
  /// ## Ticker vs Audio Engine
  ///
  /// The player supports two modes of operation:
  ///
  /// - **Test Mode (ticker provided)**: Uses ticker for simulated position updates.
  ///   Fast, deterministic, no audio hardware required.
  ///
  /// - **Production Mode (audioEngine provided, iOS only)**: Uses AVPlayer for real audio streaming.
  ///   Position updates come from actual playback, audio plays through device speakers/headphones.
  ///
  /// When both are nil, defaults to production mode with TimerTicker (simulated playback).
  #if os(iOS)
  public init(
    playbackSettings: PlaybackSettings = PlaybackSettings(),
    stateManager: EpisodeStateManager? = nil,
    chapterResolver: ((Episode, TimeInterval) -> [Chapter])? = nil,
    ticker: Ticker? = nil,
    audioEngine: AVPlayerPlaybackEngine? = nil
  ) {
    self.playbackSettings = playbackSettings
    self.episodeStateManager = stateManager ?? InMemoryEpisodeStateManager()
    self.chapterResolver = chapterResolver
    self.playbackSpeed = playbackSettings.defaultSpeed
    self.tickerFactory = { ticker ?? TimerTicker() }
    self.audioEngine = audioEngine

    #if canImport(Combine)
      self.stateSubject = CurrentValueSubject(.idle(Constants.placeholderEpisode))
    #endif
  }

  #else
  public init(
    playbackSettings: PlaybackSettings = PlaybackSettings(),
    stateManager: EpisodeStateManager? = nil,
    chapterResolver: ((Episode, TimeInterval) -> [Chapter])? = nil,
    ticker: Ticker? = nil
  ) {
    self.playbackSettings = playbackSettings
    self.episodeStateManager = stateManager ?? InMemoryEpisodeStateManager()
    self.chapterResolver = chapterResolver
    self.playbackSpeed = playbackSettings.defaultSpeed
    self.tickerFactory = { ticker ?? TimerTicker() }

    #if canImport(Combine)
      self.stateSubject = CurrentValueSubject(.idle(Constants.placeholderEpisode))
    #endif
  }
  #endif

  deinit {
    activeTicker?.cancel()  // Ensure no lingering timer
    #if os(iOS)
      audioEngine?.stop()  // Clean up audio resources
    #endif
  }

  // MARK: - EpisodePlaybackService

  public func play(episode: Episode, duration maybeDuration: TimeInterval?) {
    currentEpisode = episode
    currentDuration = resolveDuration(for: episode, override: maybeDuration)
    currentPosition = clampPosition(TimeInterval(episode.playbackPosition))
    playbackSpeed = clampSpeed(playbackSettings.defaultSpeed)
    isPlaying = true
    lastPersistenceTime = 0  // Reset throttle so next tick can persist immediately
    chapters = resolveChapters(for: episode, duration: currentDuration)
    updateCurrentChapterIndex()
    persistPlaybackPosition()
    emitState(.playing(episodeSnapshot(), position: currentPosition, duration: currentDuration))
    
    #if os(iOS)
      let isDebugAudio = ProcessInfo.processInfo.environment["UITEST_DEBUG_AUDIO"] == "1"
      // Check if audio engine is available and episode has audio URL
      if isDebugAudio {
        NSLog(
          "[TestAudio] EnhancedEpisodePlayer.play() - audioEngine: %@, episode.audioURL: %@",
          audioEngine != nil ? "present" : "nil",
          episode.audioURL?.absoluteString ?? "nil"
        )
      }

      if audioEngine != nil, let audioURL = episode.audioURL {
        // Production mode: Use actual audio playback
        if isDebugAudio {
          NSLog("[TestAudio] Starting audio engine playback with URL: %@", audioURL.absoluteString)
        }
        startAudioEnginePlayback(url: audioURL)
      } else if audioEngine != nil && episode.audioURL == nil {
        // Error: audio engine provided but no URL
      if isDebugAudio {
        NSLog("[TestAudio][Error] Audio engine present but episode.audioURL is nil - failing playback")
      }
      // Stop any existing audio before transitioning to failed state
      audioEngine?.stop()
      failPlayback(error: .missingAudioURL)
      } else {
        // Fallback: Use ticker for simulated playback
        if isDebugAudio {
          NSLog("[TestAudio] Using ticker (audioEngine nil or no URL)")
        }
        startTicker()
      }
    #else
      // Non-iOS: Always use ticker
      startTicker()
    #endif
  }

  public func pause() {
    guard currentEpisode != nil else { return }
    isPlaying = false
    
    #if os(iOS)
      if audioEngine != nil {
        audioEngine?.pause()
      } else {
        stopTicker()  // Stop position advancement
      }
    #else
      stopTicker()  // Stop position advancement
    #endif
    
    let snapshot = persistPlaybackPosition()
    lastPersistenceTime = 0  // Reset throttle so next tick after resume can persist immediately
    emitState(.paused(snapshot, position: currentPosition, duration: currentDuration))
  }

  public func seek(to position: TimeInterval) {
    guard currentDuration >= 0 else { return }

    // Stop ticker or audio engine temporarily if playing
    let wasPlaying = isPlaying
    if wasPlaying {
      #if os(iOS)
        if audioEngine != nil {
          // Audio engine handles seeking internally
        } else {
          stopTicker()
        }
      #else
        stopTicker()
      #endif
    }

    currentPosition = clampPosition(position)
    updateCurrentChapterIndex()
    
    #if os(iOS)
      // If using audio engine, seek the player
      if audioEngine != nil {
        audioEngine?.seek(to: currentPosition)
      }
    #endif
    
    let snapshot = persistPlaybackPosition()
    lastPersistenceTime = 0  // Reset throttle so next tick can persist immediately

    if hasReachedEnd() {
      finishPlayback(markPlayed: true)
    } else {
      emitState(
        isPlaying
          ? .playing(snapshot, position: currentPosition, duration: currentDuration)
          : .paused(snapshot, position: currentPosition, duration: currentDuration))

      // Restart ticker if was playing (only if not using audio engine)
      #if os(iOS)
        if wasPlaying && audioEngine == nil {
          startTicker()
        }
      #else
        if wasPlaying {
          startTicker()
        }
      #endif
    }
  }

  // MARK: - Error Handling

  public func failPlayback(error: PlaybackError = .streamFailed) {
    guard let episode = currentEpisode else { return }
    logPlaybackError(error, for: episode)
    isPlaying = false
    stopTicker()  // Stop position advancement
    #if os(iOS)
      audioEngine?.stop()  // Clean up audio engine observers and player
    #endif
    let snapshot = persistPlaybackPosition()
    emitState(
      .failed(
        snapshot,
        position: currentPosition,
        duration: currentDuration,
        error: error
      )
    )
  }

  private func logPlaybackError(_ error: PlaybackError, for episode: Episode) {
    let urlString = episode.audioURL?.absoluteString ?? "nil"
    let message = error.userMessage
    let errorText = String(describing: error)
    Self.logger.error("""
      Playback failed for episode \(episode.id, privacy: .public) "\(episode.title, privacy: .public)"
      url: \(urlString, privacy: .public)
      error: \(errorText, privacy: .public)
      message: \(message, privacy: .public)
      position: \(self.currentPosition, privacy: .public)
      duration: \(self.currentDuration, privacy: .public)
      """
    )
  }

  // MARK: - Advanced Controls

  public func skipForward(interval: TimeInterval? = nil) {
    guard currentDuration > 0 else { return }
    let delta = interval ?? playbackSettings.skipForwardInterval
    seek(to: currentPosition + delta)
  }

  public func skipBackward(interval: TimeInterval? = nil) {
    let delta = interval ?? playbackSettings.skipBackwardInterval
    seek(to: currentPosition - delta)
  }

  public func setPlaybackSpeed(_ speed: Float) {
    playbackSpeed = clampSpeed(speed)
    
    #if os(iOS)
      // Update audio engine rate if using it
      if audioEngine != nil {
        audioEngine?.setRate(playbackSpeed)
      }
    #endif

    // Emit updated state if playing to notify subscribers of speed change
    if isPlaying {
      emitState(.playing(episodeSnapshot(), position: currentPosition, duration: currentDuration))
    }
  }

  public func getCurrentPlaybackSpeed() -> Float {
    playbackSpeed
  }

  public func setSkipSilence(enabled: Bool) {
    isSkipSilenceEnabled = enabled
  }

  public func setVolumeBoost(enabled: Bool) {
    isVolumeBoostEnabled = enabled
  }

  public func jumpToChapter(_ chapter: Chapter) {
    guard let index = chapters.firstIndex(where: { $0.id == chapter.id }) else { return }
    currentChapterIndex = index
    seek(to: chapter.startTime)
  }

  public func nextChapter() {
    guard !chapters.isEmpty else { return }
    for (index, chapter) in chapters.enumerated() {
      if chapter.startTime > currentPosition + Constants.chapterPositionTolerance {
        currentChapterIndex = index
        seek(to: chapter.startTime)
        return
      }
    }
  }

  public func previousChapter() {
    guard !chapters.isEmpty else {
      seek(to: 0)
      return
    }

    var targetIndex: Int?
    for (index, chapter) in chapters.enumerated() {
      if chapter.startTime < currentPosition - Constants.chapterPositionTolerance {
        targetIndex = index
      } else {
        break
      }
    }

    if let index = targetIndex {
      currentChapterIndex = index
      seek(to: chapters[index].startTime)
    } else {
      currentChapterIndex = 0
      seek(to: 0)
    }
  }

  public func markEpisodeAs(played: Bool) {
    guard currentEpisode != nil else { return }
    updatePlayedStatus(played)
    if played {
      currentPosition = currentDuration
      finishPlayback(markPlayed: false)
    }
  }

  // MARK: - Private helpers

  private func resolveDuration(for episode: Episode, override: TimeInterval?) -> TimeInterval {
    if let override, override > 0 { return override }
    if let duration = episode.duration, duration > 0 { return duration }
    return Constants.defaultDuration
  }

  private func clampPosition(_ position: TimeInterval) -> TimeInterval {
    guard currentDuration > 0 else { return max(0, position) }
    return min(max(0, position), currentDuration)
  }

  private func clampSpeed(_ speed: Float) -> Float {
    min(max(speed, Constants.minimumSpeed), Constants.maximumSpeed)
  }

  @discardableResult
  private func persistPlaybackPosition() -> Episode {
    guard var episode = currentEpisode else { return Constants.placeholderEpisode }
    episode = episode.withPlaybackPosition(Int(currentPosition))
    currentEpisode = episode

    Task { [episodeStateManager, episode, position = currentPosition] in
      await episodeStateManager.updatePlaybackPosition(episode, position: position)
    }

    return episode
  }

  private func updatePlayedStatus(_ played: Bool) {
    guard var episode = currentEpisode else { return }
    episode = episode.withPlayedStatus(played)
    currentEpisode = episode

    Task { [episodeStateManager, episode] in
      await episodeStateManager.setPlayedStatus(episode, isPlayed: played)
    }
  }

  private func hasReachedEnd() -> Bool {
    guard currentDuration > 0 else { return false }
    return currentPosition >= currentDuration - Constants.finishTolerance
  }

  private func finishPlayback(markPlayed: Bool) {
    isPlaying = false
    stopTicker()  // Stop position advancement
    #if os(iOS)
      audioEngine?.stop()  // Clean up audio engine observers and player
    #endif
    currentPosition = currentDuration
    let snapshot = persistPlaybackPosition()
    // Note: No need to reset lastPersistenceTime here since playback has ended
    if markPlayed {
      updatePlayedStatus(true)
    }
    emitState(.finished(snapshot, duration: currentDuration))
  }

  private func resolveChapters(for episode: Episode, duration: TimeInterval) -> [Chapter] {
    if let chapterResolver {
      let resolved = chapterResolver(episode, duration).sorted { $0.startTime < $1.startTime }
      if !resolved.isEmpty { return resolved }
    }

    guard shouldGenerateAutomaticChapters(for: episode, duration: duration) else {
      return []
    }

    return generateAutomaticChapters(for: episode, duration: duration)
  }

  private func shouldGenerateAutomaticChapters(for episode: Episode, duration: TimeInterval) -> Bool
  {
    guard duration >= Constants.minimumAutoChapterDuration else { return false }
    if let description = episode.description?.lowercased(), description.contains("chapter") {
      return true
    }
    return false
  }

  private func generateAutomaticChapters(for episode: Episode, duration: TimeInterval) -> [Chapter]
  {
    guard duration > 0 else { return [] }
    let segments = max(2, Int(duration / max(Constants.minimumChapterSegment, duration / 4)))
    let segmentLength = duration / Double(segments)

    return (0..<segments).map { index in
      let start = segmentLength * Double(index)
      let end = index == segments - 1 ? duration : segmentLength * Double(index + 1)
      return Chapter(
        id: "auto_\(episode.id)_\(index)",
        title: "Chapter \(index + 1)",
        startTime: start,
        endTime: end,
        artworkURL: nil,
        linkURL: nil
      )
    }
  }

  private func updateCurrentChapterIndex() {
    guard !chapters.isEmpty else {
      currentChapterIndex = nil
      return
    }

    var lastMatch: Int?
    for (index, chapter) in chapters.enumerated() {
      if chapter.startTime <= currentPosition + Constants.chapterPositionTolerance {
        lastMatch = index
      } else {
        break
      }
    }

    currentChapterIndex = lastMatch
  }

  private func episodeSnapshot() -> Episode {
    currentEpisode ?? Constants.placeholderEpisode
  }

  private func emitState(_ state: EpisodePlaybackState) {
    #if canImport(Combine)
      stateSubject.send(state)
    #endif
  }

  public func audioDebugInfo() -> AudioDebugInfo {
    let url = currentEpisode?.audioURL
    let urlString = url?.absoluteString ?? "nil"
    let access: String
    if let url {
      if url.isFileURL {
        access = FileManager.default.isReadableFile(atPath: url.path) ? "readable" : "missing"
      } else {
        access = "remote"
      }
    } else {
      access = "none"
    }

    #if os(iOS)
      let mode = audioEngine == nil ? "ticker" : "audioEngine"
      let engineStatus = audioEngine?.debugStatusDescription ?? "none"
      let engineRate = audioEngine?.debugRateDescription ?? "none"
      let engineError = audioEngine?.debugErrorDescription ?? "none"
      let engineIsPlaying = audioEngine?.isPlaying ?? false
    #else
      let mode = "ticker"
      let engineStatus = "n/a"
      let engineRate = "n/a"
      let engineError = "n/a"
      let engineIsPlaying = false
    #endif

    return AudioDebugInfo(
      playbackMode: mode,
      audioURL: urlString,
      audioURLAccess: access,
      engineStatus: engineStatus,
      engineRate: engineRate,
      engineError: engineError,
      engineIsPlaying: engineIsPlaying,
      playerIsPlaying: isPlaying,
      position: currentPosition,
      duration: currentDuration
    )
  }
  
  // MARK: - Audio Engine Integration
  
  #if os(iOS)
  /// Start playback using the audio engine
  private func startAudioEnginePlayback(url: URL) {
    guard let audioEngine = audioEngine else { return }
    
    // Set up callbacks
    audioEngine.onPositionUpdate = { [weak self] position in
      Task { @MainActor in
        guard let self = self else { return }
        self.handleAudioEnginePositionUpdate(position)
      }
    }
    
    audioEngine.onPlaybackFinished = { [weak self] in
      Task { @MainActor in
        guard let self = self else { return }
        self.finishPlayback(markPlayed: true)
      }
    }
    
    audioEngine.onError = { [weak self] error in
      Task { @MainActor in
        guard let self = self else { return }
        self.failPlayback(error: error)
      }
    }
    
    // Start playback
    audioEngine.play(from: url, startPosition: currentPosition, rate: playbackSpeed)
  }
  
  /// Handle position update from audio engine
  private func handleAudioEnginePositionUpdate(_ position: TimeInterval) {
    guard isPlaying else { return }
    
    currentPosition = position
    updateCurrentChapterIndex()
    
    // Throttle persistence: only save every 5 seconds
    if currentPosition - lastPersistenceTime >= Constants.persistenceInterval {
      persistPlaybackPosition()
      lastPersistenceTime = currentPosition
    }
    
    // Emit updated state to all subscribers
    emitState(.playing(episodeSnapshot(), position: currentPosition, duration: currentDuration))
  }
  #endif

  // MARK: - Ticker Management

  /// Advances playback position by one tick interval and emits updated state.
  /// Called periodically by the ticker during active playback.
  private func tick() {
    // Guard: Only tick if actually playing
    guard isPlaying else { return }

    // Guard: Check if we've reached the end
    let tickInterval = Constants.tickInterval
    let delta = tickInterval * Double(playbackSpeed)
    let newPosition = currentPosition + delta

    if newPosition >= currentDuration {
      // Clamp to duration
      currentPosition = currentDuration

      // Emit final playing state before finish (for smooth UX at high speeds)
      if newPosition - currentDuration < Constants.tickInterval * 2 {
        emitState(.playing(episodeSnapshot(), position: currentPosition, duration: currentDuration))
      }

      finishPlayback(markPlayed: true)
      return
    }

    // Advance position
    currentPosition = newPosition
    updateCurrentChapterIndex()  // Update chapter if position crossed boundary

    // Throttle persistence: only save every 5 seconds
    if currentPosition - lastPersistenceTime >= Constants.persistenceInterval {
      persistPlaybackPosition()
      lastPersistenceTime = currentPosition
    }

    // Emit updated state to all subscribers
    emitState(.playing(episodeSnapshot(), position: currentPosition, duration: currentDuration))
  }

  /// Starts the position ticker for continuous playback updates.
  private func startTicker() {
    guard currentDuration > 0 else { return }
    activeTicker?.cancel()  // Cancel any existing ticker
    activeTicker = tickerFactory()  // Create new ticker from factory
    activeTicker?.schedule(every: Constants.tickInterval) { [weak self] in
      Task { @MainActor in
        self?.tick()
      }
    }
  }

  /// Stops the position ticker.
  private func stopTicker() {
    activeTicker?.cancel()
    activeTicker = nil
  }
}

extension EnhancedEpisodePlayer: EpisodePlaybackStateInjecting {
  public func injectPlaybackState(_ state: EpisodePlaybackState) {
    stopTicker()  // Stop any existing ticker before injecting new state
    switch state {
    case .idle(let episode):
      hydrateState(
        with: episode,
        position: 0,
        duration: resolveDuration(for: episode, override: episode.duration),
        isPlaying: false
      )
      emitState(.idle(episode))

    case .playing(let episode, let position, let duration):
      hydrateState(with: episode, position: position, duration: duration, isPlaying: true)
      lastPersistenceTime = 0  // Reset throttle so next tick can persist immediately
      emitState(.playing(episodeSnapshot(), position: currentPosition, duration: currentDuration))
      startTicker()  // Start ticker when restoring playing state

    case .paused(let episode, let position, let duration):
      hydrateState(with: episode, position: position, duration: duration, isPlaying: false)
      emitState(.paused(episodeSnapshot(), position: currentPosition, duration: currentDuration))

    case .finished(let episode, let duration):
      hydrateState(with: episode, position: duration, duration: duration, isPlaying: false)
      emitState(.finished(episodeSnapshot(), duration: currentDuration))
    case .failed(let episode, let position, let duration, let error):
      hydrateState(with: episode, position: position, duration: duration, isPlaying: false)
      emitState(
        .failed(
          episodeSnapshot(),
          position: currentPosition,
          duration: currentDuration,
          error: error
        )
      )
    }
  }

  private func hydrateState(
    with episode: Episode,
    position: TimeInterval,
    duration: TimeInterval,
    isPlaying: Bool
  ) {
    currentEpisode = episode
    currentDuration = max(duration, 0)
    currentPosition = clampPosition(position)
    self.isPlaying = isPlaying
    chapters = resolveChapters(for: episode, duration: currentDuration)
    updateCurrentChapterIndex()
  }
}

import CoreModels
@preconcurrency import Foundation

#if canImport(Combine)
  @preconcurrency import Combine
#endif

/// Enhanced playback engine that powers advanced controls for the episode detail surface and
/// player-focused integration tests.
@MainActor
public final class EnhancedEpisodePlayer: EpisodePlaybackService {
  private enum Constants {
    static let placeholderEpisode = Episode(id: "enhanced-placeholder", title: "Episode")
    static let finishTolerance: TimeInterval = 1.0
    static let chapterPositionTolerance: TimeInterval = 0.5
    static let minimumAutoChapterDuration: TimeInterval = 600
    static let minimumChapterSegment: TimeInterval = 90
    static let defaultDuration: TimeInterval = 300
    static let minimumSpeed: Float = 0.8
    static let maximumSpeed: Float = 5.0
  }

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
  public init(
    playbackSettings: PlaybackSettings = PlaybackSettings(),
    stateManager: EpisodeStateManager? = nil,
    chapterResolver: ((Episode, TimeInterval) -> [Chapter])? = nil
  ) {
    self.playbackSettings = playbackSettings
    self.episodeStateManager = stateManager ?? InMemoryEpisodeStateManager()
    self.chapterResolver = chapterResolver
    self.playbackSpeed = playbackSettings.defaultSpeed

    #if canImport(Combine)
      self.stateSubject = CurrentValueSubject(.idle(Constants.placeholderEpisode))
    #endif
  }

  // MARK: - EpisodePlaybackService

  public func play(episode: Episode, duration maybeDuration: TimeInterval?) {
    currentEpisode = episode
    currentDuration = resolveDuration(for: episode, override: maybeDuration)
    currentPosition = clampPosition(TimeInterval(episode.playbackPosition))
    playbackSpeed = clampSpeed(playbackSettings.defaultSpeed)
    isPlaying = true
    chapters = resolveChapters(for: episode, duration: currentDuration)
    updateCurrentChapterIndex()
    persistPlaybackPosition()
    emitState(.playing(episodeSnapshot(), position: currentPosition, duration: currentDuration))
  }

  public func pause() {
    guard currentEpisode != nil else { return }
    isPlaying = false
    let snapshot = persistPlaybackPosition()
    emitState(.paused(snapshot, position: currentPosition, duration: currentDuration))
  }

  public func seek(to position: TimeInterval) {
    guard currentDuration >= 0 else { return }
    currentPosition = clampPosition(position)
    updateCurrentChapterIndex()
    let snapshot = persistPlaybackPosition()

    if hasReachedEnd() {
      finishPlayback(markPlayed: true)
    } else {
      emitState(
        isPlaying
          ? .playing(snapshot, position: currentPosition, duration: currentDuration)
          : .paused(snapshot, position: currentPosition, duration: currentDuration))
    }
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
    currentPosition = currentDuration
    let snapshot = persistPlaybackPosition()
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
}

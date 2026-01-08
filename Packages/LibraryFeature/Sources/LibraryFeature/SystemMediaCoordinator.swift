#if os(iOS)
import AVFoundation
import CoreModels
import Foundation
import MediaPlayer
import Persistence
import PlaybackEngine
import SharedUtilities
import UIKit

#if canImport(Combine)
  @preconcurrency import CombineSupport
#endif

@MainActor
public final class SystemMediaCoordinator {
  public typealias ArtworkDataLoader = @Sendable (URL) async -> Data?

  private struct AudioSessionObservers {
    let interruptionObserver: NSObjectProtocol
    let routeObserver: NSObjectProtocol
    let debugInterruptionObserver: NSObjectProtocol?
  }

  private final class MainActorCleanupToken {
    private let cleanup: @MainActor () -> Void

    init(_ cleanup: @escaping @MainActor () -> Void) {
      self.cleanup = cleanup
    }

    deinit {
      let cleanup = cleanup
      Task { @MainActor in
        cleanup()
      }
    }
  }

  private let playbackService: EpisodePlaybackService & EpisodeTransportControlling
  private let settingsRepository: SettingsRepository?
  private let infoBuilder = NowPlayingInfoBuilder()
  private let infoCenter = MPNowPlayingInfoCenter.default()
  private let commandCenter = MPRemoteCommandCenter.shared()
  private let audioSession = AVAudioSession.sharedInstance()
  private let artworkDataLoader: ArtworkDataLoader
  private var cleanupToken: MainActorCleanupToken?

  private var stateCancellable: AnyCancellable?
  private var lastArtworkURL: URL?
  private var artworkTask: Task<Void, Never>?
  private var skipIntervalsTask: Task<Void, Never>?

  private var currentEpisode: Episode?
  private var currentPosition: TimeInterval = 0
  private var currentDuration: TimeInterval = 0
  private var isPlaying: Bool = false
  private var hasActivePlayback: Bool = false
  private var wasPlayingBeforeInterruption = false
  private var skipForwardInterval: TimeInterval = 30
  private var skipBackwardInterval: TimeInterval = 15

  private lazy var remoteHandler = RemoteCommandHandler(
    play: { [weak self] in self?.resumePlayback() },
    pause: { [weak self] in self?.playbackService.pause() },
    togglePlayPause: { [weak self] in self?.togglePlayPause() },
    skipForward: { [weak self] interval in
      self?.playbackService.skipForward(interval: interval ?? self?.skipForwardInterval)
    },
    skipBackward: { [weak self] interval in
      self?.playbackService.skipBackward(interval: interval ?? self?.skipBackwardInterval)
    }
  )

  public init(
    playbackService: EpisodePlaybackService & EpisodeTransportControlling,
    settingsRepository: SettingsRepository? = nil,
    artworkDataLoader: @escaping ArtworkDataLoader = SystemMediaCoordinator.fetchArtworkData
  ) {
    self.playbackService = playbackService
    self.settingsRepository = settingsRepository
    self.artworkDataLoader = artworkDataLoader
    let commandCenter = MPRemoteCommandCenter.shared()

    configureAudioSession()
    configureRemoteCommands()
    let observers = registerAudioSessionObservers()
    cleanupToken = MainActorCleanupToken { [commandCenter] in
      NotificationCenter.default.removeObserver(observers.interruptionObserver)
      NotificationCenter.default.removeObserver(observers.routeObserver)
      if let debugObserver = observers.debugInterruptionObserver {
        NotificationCenter.default.removeObserver(debugObserver)
      }
      commandCenter.playCommand.removeTarget(nil)
      commandCenter.pauseCommand.removeTarget(nil)
      commandCenter.togglePlayPauseCommand.removeTarget(nil)
      commandCenter.skipForwardCommand.removeTarget(nil)
      commandCenter.skipBackwardCommand.removeTarget(nil)
    }
    subscribeToPlaybackState()
    loadSkipIntervals()
  }

  deinit {
    artworkTask?.cancel()
    skipIntervalsTask?.cancel()
  }

  // MARK: - Setup

  private func subscribeToPlaybackState() {
    #if canImport(Combine)
      stateCancellable = playbackService.statePublisher
        .receive(on: RunLoop.main)
        .sink { [weak self] state in
          self?.handlePlaybackStateChange(state)
        }
    #endif
  }

  private func configureAudioSession() {
    do {
      try audioSession.setCategory(
        .playback,
        mode: .spokenAudio,
        options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
      )
    } catch {
      Logger.warning("Failed to configure audio session: \(error)")
    }
  }

  private func registerAudioSessionObservers() -> AudioSessionObservers {
    let interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self else { return }
      guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
      else {
        return
      }

      let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
      Task { @MainActor in
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
        self.handleInterruption(type: type, shouldResume: options.contains(.shouldResume))
      }
    }

    let routeObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self else { return }
      guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
      else {
        return
      }

      Task { @MainActor in
        if reason == .oldDeviceUnavailable {
          self.playbackService.pause()
        }
      }
    }

    return AudioSessionObservers(
      interruptionObserver: interruptionObserver,
      routeObserver: routeObserver,
      debugInterruptionObserver: registerDebugInterruptionObserver()
    )
  }

  private func registerDebugInterruptionObserver() -> NSObjectProtocol? {
    guard ProcessInfo.processInfo.environment["UITEST_PLAYBACK_DEBUG"] == "1" else {
      return nil
    }

    return NotificationCenter.default.addObserver(
      forName: .playbackDebugInterruption,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self else { return }
      let userInfo = notification.userInfo
      let rawType = userInfo?[PlaybackDebugNotificationKey.interruptionType] as? String
      let shouldResume = userInfo?[PlaybackDebugNotificationKey.shouldResume] as? Bool ?? false
      guard let rawType,
            let type = PlaybackDebugInterruptionType(rawValue: rawType) else {
        return
      }
      Task { @MainActor in
        let sessionType: AVAudioSession.InterruptionType = (type == .began) ? .began : .ended
        self.handleInterruption(type: sessionType, shouldResume: shouldResume)
      }
    }
  }

  private func handleInterruption(
    type: AVAudioSession.InterruptionType,
    shouldResume: Bool
  ) {
    switch type {
    case .began:
      wasPlayingBeforeInterruption = isPlaying
      if isPlaying {
        playbackService.pause()
      }
    case .ended:
      if shouldResume, wasPlayingBeforeInterruption {
        resumePlayback()
      }
      wasPlayingBeforeInterruption = false
    @unknown default:
      wasPlayingBeforeInterruption = false
    }
  }

  private func configureRemoteCommands() {
    commandCenter.playCommand.isEnabled = false
    commandCenter.pauseCommand.isEnabled = false
    commandCenter.togglePlayPauseCommand.isEnabled = false
    commandCenter.skipForwardCommand.isEnabled = false
    commandCenter.skipBackwardCommand.isEnabled = false

    commandCenter.playCommand.addTarget { [weak self] _ in
      Task { @MainActor in
        self?.remoteHandler.handle(.play)
      }
      return .success
    }

    commandCenter.pauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in
        self?.remoteHandler.handle(.pause)
      }
      return .success
    }

    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      Task { @MainActor in
        self?.remoteHandler.handle(.togglePlayPause)
      }
      return .success
    }

    commandCenter.skipForwardCommand.addTarget { [weak self] event in
      let interval = (event as? MPSkipIntervalCommandEvent)?.interval
      Task { @MainActor in
        self?.remoteHandler.handle(.skipForward, interval: interval)
      }
      return .success
    }

    commandCenter.skipBackwardCommand.addTarget { [weak self] event in
      let interval = (event as? MPSkipIntervalCommandEvent)?.interval
      Task { @MainActor in
        self?.remoteHandler.handle(.skipBackward, interval: interval)
      }
      return .success
    }

    updateRemoteCommandIntervals()
  }

  private func updateRemoteCommandIntervals() {
    commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForwardInterval)]
    commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBackwardInterval)]
  }

  private func loadSkipIntervals() {
    guard let settingsRepository else { return }

    // Cancel any previous load task
    skipIntervalsTask?.cancel()

    // Create new load task and store reference for later cancellation
    skipIntervalsTask = Task { @MainActor [weak self] in
      let settings = await settingsRepository.loadGlobalPlaybackSettings()
      guard let self else { return }
      if let forward = settings.skipForwardInterval {
        self.skipForwardInterval = TimeInterval(forward)
      }
      if let backward = settings.skipBackwardInterval {
        self.skipBackwardInterval = TimeInterval(backward)
      }
      self.updateRemoteCommandIntervals()
    }
  }

  // MARK: - Playback State Handling

  private func handlePlaybackStateChange(_ state: EpisodePlaybackState) {
    updatePlaybackTracking(state)
    updateNowPlayingInfo(for: state)
    updateRemoteCommandAvailability()
    updateAudioSessionActive(for: state)
  }

  private func updatePlaybackTracking(_ state: EpisodePlaybackState) {
    switch state {
    case .idle:
      currentEpisode = nil
      currentPosition = 0
      currentDuration = 0
      isPlaying = false
      hasActivePlayback = false

    case .playing(let episode, let position, let duration):
      currentEpisode = episode
      currentPosition = position
      currentDuration = duration
      isPlaying = true
      hasActivePlayback = true

    case .paused(let episode, let position, let duration):
      currentEpisode = episode
      currentPosition = position
      currentDuration = duration
      isPlaying = false
      hasActivePlayback = true

    case .finished(let episode, let duration):
      currentEpisode = episode
      currentPosition = duration
      currentDuration = duration
      isPlaying = false
      hasActivePlayback = false

    case .failed(let episode, let position, let duration, _):
      currentEpisode = episode
      currentPosition = position
      currentDuration = duration
      isPlaying = false
      hasActivePlayback = false
    }
  }

  private func updateNowPlayingInfo(for state: EpisodePlaybackState) {
    guard let snapshot = infoBuilder.makeSnapshot(from: state) else {
      infoCenter.nowPlayingInfo = nil
      infoCenter.playbackState = .stopped
      return
    }

    var info: [String: Any] = [
      MPMediaItemPropertyTitle: snapshot.title,
      MPMediaItemPropertyPlaybackDuration: snapshot.duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: snapshot.elapsed,
      MPNowPlayingInfoPropertyPlaybackRate: snapshot.playbackRate,
    ]

    if !snapshot.podcastTitle.isEmpty {
      info[MPMediaItemPropertyAlbumTitle] = snapshot.podcastTitle
      info[MPMediaItemPropertyArtist] = snapshot.podcastTitle
    }

    infoCenter.nowPlayingInfo = info
    infoCenter.playbackState = snapshot.playbackRate > 0 ? .playing : .paused

    updateArtwork(for: snapshot)
  }

  private func updateArtwork(for snapshot: NowPlayingInfoSnapshot) {
    guard let url = snapshot.artworkURL else {
      lastArtworkURL = nil
      if var info = infoCenter.nowPlayingInfo {
        info.removeValue(forKey: MPMediaItemPropertyArtwork)
        infoCenter.nowPlayingInfo = info
      }
      return
    }

    guard url != lastArtworkURL else { return }
    lastArtworkURL = url
    artworkTask?.cancel()

    artworkTask = Task { [weak self] in
      guard let self else { return }
      guard let data = await self.artworkDataLoader(url) else { return }
      await MainActor.run { [weak self] in
        guard let self else { return }
        guard let artwork = Self.makeArtwork(from: data) else { return }
        self.applyArtwork(artwork)
      }
    }
  }

  private func applyArtwork(_ artwork: MPMediaItemArtwork) {
    guard var info = infoCenter.nowPlayingInfo else { return }
    info[MPMediaItemPropertyArtwork] = artwork
    infoCenter.nowPlayingInfo = info
  }

  private nonisolated static func makeArtwork(from data: Data) -> MPMediaItemArtwork? {
    guard let image = UIImage(data: data) else { return nil }
    let size = image.size
    return MPMediaItemArtwork(boundsSize: size) { _ in image }
  }

  public nonisolated static func fetchArtworkData(from url: URL) async -> Data? {
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      return Task.isCancelled ? nil : data
    } catch {
      Logger.warning("Failed to load artwork data for now playing: \(error)")
      return nil
    }
  }

  private func updateRemoteCommandAvailability() {
    commandCenter.playCommand.isEnabled = hasActivePlayback && !isPlaying
    commandCenter.pauseCommand.isEnabled = hasActivePlayback && isPlaying
    commandCenter.togglePlayPauseCommand.isEnabled = hasActivePlayback
    commandCenter.skipForwardCommand.isEnabled = hasActivePlayback
    commandCenter.skipBackwardCommand.isEnabled = hasActivePlayback
  }

  private func updateAudioSessionActive(for state: EpisodePlaybackState) {
    let shouldActivate: Bool

    switch state {
    case .playing, .paused:
      shouldActivate = true
    case .idle, .finished, .failed:
      shouldActivate = false
    }

    do {
      try audioSession.setActive(shouldActivate, options: [.notifyOthersOnDeactivation])
    } catch {
      Logger.warning("Failed to update audio session active state: \(error)")
    }
  }

  private func togglePlayPause() {
    if isPlaying {
      playbackService.pause()
    } else {
      resumePlayback()
    }
  }

  private func resumePlayback() {
    guard let episode = currentEpisode else { return }
    let duration = currentDuration > 0 ? currentDuration : episode.duration
    playbackService.play(episode: episode, duration: duration)

    if currentPosition > 0 {
      playbackService.seek(to: currentPosition)
    }
  }


}

#endif

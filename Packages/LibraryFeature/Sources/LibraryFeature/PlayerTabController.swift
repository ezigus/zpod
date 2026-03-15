#if canImport(PlayerFeature)
import CoreModels
import Foundation
import OSLog
import PlaybackEngine
import PlayerFeature
import SharedUtilities

@MainActor
final class PlayerTabController: ObservableObject {
  private static let debugLogger = Logger(subsystem: "us.zig.zpod.library", category: "PlayerTab")

  private let playbackService: EpisodePlaybackService & EpisodeTransportControlling
  private let logger = PlayerTabController.debugLogger
  nonisolated(unsafe) private var playNotificationObserver: NSObjectProtocol?
  private let enablesDebugPlayHook: Bool

  let sampleEpisode: Episode
  lazy var detailViewModel: EpisodeDetailViewModel = {
    let handlers = EpisodeDetailViewModel.PlaybackCommandHandlers(
      play: { [weak self] episode, position, duration in
        self?.playSampleEpisode(episode: episode, position: position, duration: duration)
      },
      pause: { [weak self] in
        self?.pause()
      },
      skipForward: { [weak self] interval in
        self?.skipForward(interval: interval)
      },
      skipBackward: { [weak self] interval in
        self?.skipBackward(interval: interval)
      },
      seek: { [weak self] position in
        self?.seek(to: position)
      }
    )
    let viewModel = EpisodeDetailViewModel(
      playbackService: playbackService,
      playbackHandlers: handlers
    )
    viewModel.loadEpisode(sampleEpisode)
    return viewModel
  }()

  init(playbackService: EpisodePlaybackService & EpisodeTransportControlling = PlaybackEnvironment.playbackService) {
    self.playbackService = playbackService
    self.enablesDebugPlayHook = ProcessInfo.processInfo.environment["UITEST_POSITION_DEBUG"] == "1"
    self.sampleEpisode = PlayerTabController.resolveSampleEpisode()
    _ = detailViewModel
    if enablesDebugPlayHook {
      playNotificationObserver = NotificationCenter.default.addObserver(
        forName: .playerTabPlaySampleRequested,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.playSampleEpisode() }
      }
    }
  }

  deinit {
    if let observer = playNotificationObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func playSampleEpisode() {
    let position = detailViewModel.currentPosition
    let duration = sampleEpisode.duration ?? 300
    let resumeEpisode = sampleEpisode.withPlaybackPosition(Int(position))
    playSampleEpisode(
      episode: resumeEpisode,
      position: position,
      duration: duration
    )
  }

  private func playSampleEpisode(
    episode: Episode,
    position: TimeInterval,
    duration: TimeInterval
  ) {
    logger.info("PlayerTabController.playSampleEpisode id=\(episode.id, privacy: .public) position=\(position, privacy: .public) duration=\(duration, privacy: .public)")
    NSLog("[PlayerTab] playSampleEpisode id=%@ position=%.02f duration=%.02f", episode.id, position, duration)
    playbackService.play(episode: episode, duration: duration)
    if position > 0 {
      playbackService.seek(to: position)
    }
  }

  private func pause() {
    logger.info("PlayerTabController.pause()")
    playbackService.pause()
  }

  private func skipForward(interval: TimeInterval?) {
    playbackService.skipForward(interval: interval)
  }

  private func skipBackward(interval: TimeInterval?) {
    playbackService.skipBackward(interval: interval)
  }

  private func seek(to position: TimeInterval) {
    playbackService.seek(to: position)
  }

  private static func resolveSampleEpisode() -> Episode {
    let env = ProcessInfo.processInfo.environment
    let audioVariant = env["UITEST_AUDIO_VARIANT"]?.lowercased() ?? "short"
    let disableFallback = env["UITEST_AUDIO_OVERRIDE_MODE"] == "missing"
      || env["UITEST_AUDIO_DISABLE_BUNDLE"] == "1"
      || (env["UITEST_AUDIO_OVERRIDE_URL"]?.isEmpty == false)
    let audioURL: URL?
    let duration: TimeInterval
    switch audioVariant {
    case "long":
      audioURL = resolveTestAudioURL(
        envKey: "UITEST_AUDIO_LONG_PATH",
        bundleName: "test-episode-long",
        env: env
      )
      duration = 20.0
    case "medium":
      audioURL = resolveTestAudioURL(
        envKey: "UITEST_AUDIO_MEDIUM_PATH",
        bundleName: "test-episode-medium",
        env: env
      )
      duration = 15.0
    default:
      audioURL = resolveTestAudioURL(
        envKey: "UITEST_AUDIO_SHORT_PATH",
        bundleName: "test-episode-short",
        env: env
      )
      duration = 6.523
    }

    let finalAudioURL: URL?
    if disableFallback {
      finalAudioURL = audioURL
    } else {
      finalAudioURL = audioURL ?? URL(string: "https://example.com/episode.mp3")
    }

    if env["UITEST_DEBUG_AUDIO"] == "1" {
      persistSampleEpisodeDebugInfo(
        audioURL: finalAudioURL,
        disableFallback: disableFallback,
        variant: audioVariant,
        environment: env
      )
    }

    return Episode(
      id: "sample-1",
      title: "Sample Episode",
      podcastID: "sample-podcast",
      podcastTitle: "Sample Podcast",
      playbackPosition: 0,
      isPlayed: false,
      pubDate: Date(),
      duration: duration,
      description: "This is a sample episode to demonstrate the player interface.",
      audioURL: finalAudioURL
    )
  }

  private static func persistSampleEpisodeDebugInfo(
    audioURL: URL?,
    disableFallback: Bool,
    variant: String,
    environment env: [String: String]
  ) {
    let debugDirectory = URL(fileURLWithPath: "/tmp/zpod-uitest-debug")
    try? FileManager.default.createDirectory(
      at: debugDirectory,
      withIntermediateDirectories: true
    )
    let debugFile = debugDirectory.appendingPathComponent("player-tab-audio-info.json")
    if let url = audioURL {
      if url.isFileURL {
        let readable = FileManager.default.isReadableFile(atPath: url.path)
        let message = "PlayerTab sample episode resolved file URL=\(url.path) readable=\(readable) disableFallback=\(disableFallback) variant=\(variant)"
        debugLogger.info("\(message, privacy: .public)")
        NSLog("[TestAudio] %@", message)
        writeDebugInfo(
          [
            "url": url.path,
            "type": "file",
            "readable": readable ? "true" : "false",
            "disableFallback": String(disableFallback),
            "variant": variant
          ],
          to: debugFile
        )
      } else {
        let message = "PlayerTab sample episode resolved remote URL=\(url.absoluteString) disableFallback=\(disableFallback) variant=\(variant)"
        debugLogger.info("\(message, privacy: .public)")
        NSLog("[TestAudio] %@", message)
        writeDebugInfo(
          [
            "url": url.absoluteString,
            "type": "remote",
            "disableFallback": String(disableFallback),
            "variant": variant
          ],
          to: debugFile
        )
      }
    } else {
      let message = "PlayerTab sample episode audioURL is nil (disableFallback=\(disableFallback) variant=\(variant))"
      debugLogger.error("\(message, privacy: .public)")
      NSLog("[TestAudio] %@", message)
      writeDebugInfo(
        [
          "url": "nil",
          "type": "none",
          "disableFallback": String(disableFallback),
          "variant": variant,
          "overrideMode": env["UITEST_AUDIO_OVERRIDE_MODE"] ?? "nil",
          "disableBundle": env["UITEST_AUDIO_DISABLE_BUNDLE"] ?? "nil",
          "overrideURL": env["UITEST_AUDIO_OVERRIDE_URL"] ?? "nil"
        ],
        to: debugFile
      )
    }
  }

  private static func writeDebugInfo(_ info: [String: String], to url: URL) {
    do {
      let data = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted])
      try data.write(to: url, options: .atomic)
    } catch {
      NSLog("[TestAudio] Failed to persist player tab debug info: %@", error.localizedDescription)
    }
  }

  private static func resolveTestAudioURL(
    envKey: String,
    bundleName: String,
    env: [String: String]
  ) -> URL? {
    let isDebugAudio = env["UITEST_DEBUG_AUDIO"] == "1"
    if env["UITEST_AUDIO_OVERRIDE_MODE"] == "missing" {
      if isDebugAudio { NSLog("Audio override mode=missing for %@", envKey) }
      return nil
    }
    if let overrideValue = env["UITEST_AUDIO_OVERRIDE_URL"], !overrideValue.isEmpty {
      if let overrideURL = URL(string: overrideValue), overrideURL.scheme != nil {
        if isDebugAudio { NSLog("Audio override URL resolved: %@", overrideURL.absoluteString) }
        return overrideURL
      }
      let fileURL = URL(fileURLWithPath: overrideValue)
      if FileManager.default.isReadableFile(atPath: fileURL.path) {
        if isDebugAudio { NSLog("Audio override file resolved: %@", fileURL.path) }
        return fileURL
      } else if isDebugAudio {
        NSLog("Audio override file missing: %@", overrideValue)
      }
    }
    if let path = env[envKey] {
      let url = URL(fileURLWithPath: path)
      if FileManager.default.isReadableFile(atPath: url.path) {
        if isDebugAudio { NSLog("Audio env resolved: %@ -> %@", envKey, url.path) }
        return url
      } else if isDebugAudio {
        NSLog("Audio env missing file: %@ -> %@", envKey, path)
      }
    }
    if env["UITEST_AUDIO_DISABLE_BUNDLE"] == "1" {
      if isDebugAudio { NSLog("Audio bundle fallback disabled for %@", bundleName) }
      return nil
    }
    if let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "m4a") {
      if isDebugAudio { NSLog("Audio bundle resolved: %@ -> %@", bundleName, bundleURL.path) }
      return bundleURL
    }
    if isDebugAudio { NSLog("Audio not found for env=%@ bundle=%@", envKey, bundleName) }
    return nil
  }
}
#endif

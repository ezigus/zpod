import Foundation

public struct PlaybackPreset: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var description: String?
    public var playbackSpeed: Double
    public var skipForwardInterval: Int
    public var skipBackwardInterval: Int
    public var skipIntroSeconds: Int
    public var skipOutroSeconds: Int
    public var continuousPlayback: Bool
    public var crossFadeEnabled: Bool
    public var crossFadeDuration: Double
    public var autoMarkAsPlayed: Bool
    public var playedThreshold: Double

    public init(
        id: String,
        name: String,
        description: String? = nil,
        playbackSpeed: Double = 1.0,
        skipForwardInterval: Int = 30,
        skipBackwardInterval: Int = 15,
        skipIntroSeconds: Int = 0,
        skipOutroSeconds: Int = 0,
        continuousPlayback: Bool = true,
        crossFadeEnabled: Bool = false,
        crossFadeDuration: Double = 2.0,
        autoMarkAsPlayed: Bool = false,
        playedThreshold: Double = 0.9
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.playbackSpeed = playbackSpeed
        self.skipForwardInterval = skipForwardInterval
        self.skipBackwardInterval = skipBackwardInterval
        self.skipIntroSeconds = skipIntroSeconds
        self.skipOutroSeconds = skipOutroSeconds
        self.continuousPlayback = continuousPlayback
        self.crossFadeEnabled = crossFadeEnabled
        self.crossFadeDuration = crossFadeDuration
        self.autoMarkAsPlayed = autoMarkAsPlayed
        self.playedThreshold = playedThreshold
    }
}

public struct PlaybackPresetLibrary: Codable, Equatable, Sendable {
    public var builtInPresets: [PlaybackPreset]
    public var customPresets: [PlaybackPreset]
    public var activePresetID: String?

    public init(
        builtInPresets: [PlaybackPreset] = PlaybackPresetLibrary.defaultBuiltInPresets,
        customPresets: [PlaybackPreset] = [],
        activePresetID: String? = nil
    ) {
        self.builtInPresets = builtInPresets
        self.customPresets = customPresets
        self.activePresetID = activePresetID
    }

    public var allPresets: [PlaybackPreset] {
        builtInPresets + customPresets
    }

    public static let `default` = PlaybackPresetLibrary()

    public static let defaultBuiltInPresets: [PlaybackPreset] = [
        PlaybackPreset(
            id: "balanced",
            name: "Balanced",
            description: "Default experience with moderate skips.",
            playbackSpeed: 1.0,
            skipForwardInterval: 30,
            skipBackwardInterval: 15,
            skipIntroSeconds: 15,
            skipOutroSeconds: 15,
            continuousPlayback: true,
            crossFadeEnabled: false,
            crossFadeDuration: 1.5,
            autoMarkAsPlayed: true,
            playedThreshold: 0.9
        ),
        PlaybackPreset(
            id: "speed-listener",
            name: "Speed Listener",
            description: "Faster playback with shorter skips.",
            playbackSpeed: 1.5,
            skipForwardInterval: 45,
            skipBackwardInterval: 20,
            skipIntroSeconds: 25,
            skipOutroSeconds: 20,
            continuousPlayback: true,
            crossFadeEnabled: true,
            crossFadeDuration: 1.0,
            autoMarkAsPlayed: true,
            playedThreshold: 0.85
        ),
        PlaybackPreset(
            id: "deep-dive",
            name: "Deep Dive",
            description: "Slower speed with minimal skipping for long-form shows.",
            playbackSpeed: 0.9,
            skipForwardInterval: 15,
            skipBackwardInterval: 10,
            skipIntroSeconds: 5,
            skipOutroSeconds: 5,
            continuousPlayback: false,
            crossFadeEnabled: false,
            crossFadeDuration: 0.5,
            autoMarkAsPlayed: false,
            playedThreshold: 0.95
        )
    ]
}

public extension PlaybackPreset {
    func applying(to settings: PlaybackSettings) -> PlaybackSettings {
        PlaybackSettings(
            playbackSpeed: playbackSpeed,
            skipIntroSeconds: skipIntroSeconds,
            skipOutroSeconds: skipOutroSeconds,
            continuousPlayback: continuousPlayback,
            crossFadeEnabled: crossFadeEnabled,
            crossFadeDuration: crossFadeDuration,
            volumeBoostEnabled: settings.volumeBoostEnabled,
            smartSpeedEnabled: settings.smartSpeedEnabled,
            globalPlaybackSpeed: settings.globalPlaybackSpeed,
            podcastPlaybackSpeeds: settings.podcastPlaybackSpeeds,
            skipForwardInterval: skipForwardInterval,
            skipBackwardInterval: skipBackwardInterval,
            introSkipDurations: settings.introSkipDurations,
            outroSkipDurations: settings.outroSkipDurations,
            autoMarkAsPlayed: autoMarkAsPlayed,
            playedThreshold: playedThreshold,
            activePresetID: id
        )
    }
}


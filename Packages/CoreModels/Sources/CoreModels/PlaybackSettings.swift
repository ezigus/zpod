@preconcurrency import Foundation

/// Notification delivery cadence.
public enum NotificationDeliverySchedule: String, CaseIterable, Codable, Sendable {
    case immediate
    case batched
    case dailyDigest
    case weeklySummary

    public var localizedDescription: String {
        switch self {
        case .immediate:
            return "Immediate"
        case .batched:
            return "Batched"
        case .dailyDigest:
            return "Daily Digest"
        case .weeklySummary:
            return "Weekly Summary"
        }
    }
}

/// Global notification settings
public struct NotificationSettings: Codable, Equatable, Sendable {
    public var newEpisodeNotificationsEnabled: Bool
    public var downloadCompleteNotificationsEnabled: Bool
    public var playbackNotificationsEnabled: Bool
    public var quietHoursEnabled: Bool
    public var quietHoursStart: String // "HH:mm" format
    public var quietHoursEnd: String // "HH:mm" format
    public var soundEnabled: Bool?
    public var customSounds: [String: String]?
    public var deliverySchedule: NotificationDeliverySchedule
    public var focusModeIntegrationEnabled: Bool
    public var liveActivitiesEnabled: Bool
    
    public init(
        newEpisodeNotificationsEnabled: Bool = true,
        downloadCompleteNotificationsEnabled: Bool = true,
        playbackNotificationsEnabled: Bool = true,
        quietHoursEnabled: Bool = false,
        quietHoursStart: String = "22:00",
        quietHoursEnd: String = "08:00",
        soundEnabled: Bool? = nil,
        customSounds: [String: String]? = nil,
        deliverySchedule: NotificationDeliverySchedule = .immediate,
        focusModeIntegrationEnabled: Bool = false,
        liveActivitiesEnabled: Bool = true
    ) {
        self.newEpisodeNotificationsEnabled = newEpisodeNotificationsEnabled
        self.downloadCompleteNotificationsEnabled = downloadCompleteNotificationsEnabled
        self.playbackNotificationsEnabled = playbackNotificationsEnabled
        self.quietHoursEnabled = quietHoursEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.soundEnabled = soundEnabled
        self.customSounds = customSounds
        self.deliverySchedule = deliverySchedule
        self.focusModeIntegrationEnabled = focusModeIntegrationEnabled
        self.liveActivitiesEnabled = liveActivitiesEnabled
    }
    
    public static let `default` = NotificationSettings()
}

/// Global playback settings
public struct PlaybackSettings: Codable, Equatable, Sendable {
    public var playbackSpeed: Double
    public var skipIntroSeconds: Int
    public var skipOutroSeconds: Int
    public var continuousPlayback: Bool
    public var crossFadeEnabled: Bool
    public var crossFadeDuration: Double
    public var volumeBoostEnabled: Bool
    public var smartSpeedEnabled: Bool
    public var globalPlaybackSpeed: Double?
    public var podcastPlaybackSpeeds: [String: Double]?
    public var skipForwardInterval: Int?
    public var skipBackwardInterval: Int?
    public var introSkipDurations: [String: Int]?
    public var outroSkipDurations: [String: Int]?
    public var autoMarkAsPlayed: Bool?
    public var playedThreshold: Double?
    
    public init(
        playbackSpeed: Double = 1.0,
        skipIntroSeconds: Int = 0,
        skipOutroSeconds: Int = 0,
        continuousPlayback: Bool = true,
        crossFadeEnabled: Bool = false,
        crossFadeDuration: Double = 2.0,
        volumeBoostEnabled: Bool = false,
        smartSpeedEnabled: Bool = false,
        globalPlaybackSpeed: Double? = nil,
        podcastPlaybackSpeeds: [String: Double]? = nil,
        skipForwardInterval: Int? = nil,
        skipBackwardInterval: Int? = nil,
        introSkipDurations: [String: Int]? = nil,
        outroSkipDurations: [String: Int]? = nil,
        autoMarkAsPlayed: Bool? = nil,
        playedThreshold: Double? = nil
    ) {
        self.playbackSpeed = playbackSpeed
        self.skipIntroSeconds = skipIntroSeconds
        self.skipOutroSeconds = skipOutroSeconds
        self.continuousPlayback = continuousPlayback
        self.crossFadeEnabled = crossFadeEnabled
        self.crossFadeDuration = crossFadeDuration
        self.volumeBoostEnabled = volumeBoostEnabled
        self.smartSpeedEnabled = smartSpeedEnabled
        self.globalPlaybackSpeed = globalPlaybackSpeed
        self.podcastPlaybackSpeeds = podcastPlaybackSpeeds
        self.skipForwardInterval = skipForwardInterval
        self.skipBackwardInterval = skipBackwardInterval
        self.introSkipDurations = introSkipDurations
        self.outroSkipDurations = outroSkipDurations
        self.autoMarkAsPlayed = autoMarkAsPlayed
        self.playedThreshold = playedThreshold
    }
}

/// Per-podcast playback settings that override global settings
public struct PodcastPlaybackSettings: Codable, Equatable, Sendable {
    public var speed: Double?
    public var introSkipDuration: Int?
    public var outroSkipDuration: Int?
    public var skipForwardInterval: Int?
    public var skipBackwardInterval: Int?
}

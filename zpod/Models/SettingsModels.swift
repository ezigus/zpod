import Foundation

/// Validation constants for settings values
public struct ValidationConstants: Sendable {
    // Playback speed validation
    public static let minPlaybackSpeed: Float = 0.8
    public static let maxPlaybackSpeed: Float = 5.0
    
    // Skip interval validation (in seconds)
    public static let minSkipInterval: TimeInterval = 5
    public static let maxSkipInterval: TimeInterval = 300
    
    // Download concurrency validation
    public static let minConcurrentDownloads = 1
    public static let maxConcurrentDownloads = 10
    
    // Retention policy validation
    public static let minRetentionDays = 1
    public static let maxRetentionDays = 365
}

/// Retention policy for downloaded episodes
public enum RetentionPolicy: Codable, Equatable, Sendable {
    case keepAll
    case keepLatest(Int)
    case deleteAfterDays(Int)
    case deleteAfterPlayed
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "keepAll":
            self = .keepAll
        case "keepLatest":
            let count = try container.decode(Int.self, forKey: .value)
            self = .keepLatest(max(1, count))  // Validate minimum
        case "deleteAfterDays":
            let days = try container.decode(Int.self, forKey: .value)
            self = .deleteAfterDays(max(ValidationConstants.minRetentionDays, min(ValidationConstants.maxRetentionDays, days)))  // Validate range
        case "deleteAfterPlayed":
            self = .deleteAfterPlayed
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown retention policy type: \(type)")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .keepAll:
            try container.encode("keepAll", forKey: .type)
        case .keepLatest(let count):
            try container.encode("keepLatest", forKey: .type)
            try container.encode(count, forKey: .value)
        case .deleteAfterDays(let days):
            try container.encode("deleteAfterDays", forKey: .type)
            try container.encode(days, forKey: .value)
        case .deleteAfterPlayed:
            try container.encode("deleteAfterPlayed", forKey: .type)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }
}

/// Update frequency for podcast feed refresh
public enum UpdateFrequency: String, CaseIterable, Codable, Sendable {
    case fifteenMinutes = "15min"
    case thirtyMinutes = "30min"
    case hourly = "1h"
    case every3Hours = "3h"
    case every6Hours = "6h"
    case every12Hours = "12h"
    case daily = "24h"
    case every3Days = "3d"
    case weekly = "7d"
    case manual = "manual"
    
    /// Convert frequency to time interval in seconds
    public var timeInterval: TimeInterval? {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .hourly: return 60 * 60
        case .every3Hours: return 3 * 60 * 60
        case .every6Hours: return 6 * 60 * 60
        case .every12Hours: return 12 * 60 * 60
        case .daily: return 24 * 60 * 60
        case .every3Days: return 3 * 24 * 60 * 60
        case .weekly: return 7 * 24 * 60 * 60
        case .manual: return nil // No automatic refresh
        }
    }
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .fifteenMinutes: return "Every 15 minutes"
        case .thirtyMinutes: return "Every 30 minutes"
        case .hourly: return "Every hour"
        case .every3Hours: return "Every 3 hours"
        case .every6Hours: return "Every 6 hours"
        case .every12Hours: return "Every 12 hours"
        case .daily: return "Daily"
        case .every3Days: return "Every 3 days"
        case .weekly: return "Weekly"
        case .manual: return "Manual only"
        }
    }
}

/// Global download preferences
public struct DownloadSettings: Codable, Equatable, Sendable {
    public let autoDownloadEnabled: Bool
    public let wifiOnly: Bool
    public let maxConcurrentDownloads: Int
    public let retentionPolicy: RetentionPolicy
    public let defaultUpdateFrequency: UpdateFrequency
    
    public init(
        autoDownloadEnabled: Bool,
        wifiOnly: Bool,
        maxConcurrentDownloads: Int,
        retentionPolicy: RetentionPolicy,
        defaultUpdateFrequency: UpdateFrequency = .every6Hours
    ) {
        self.autoDownloadEnabled = autoDownloadEnabled
        self.wifiOnly = wifiOnly
        self.maxConcurrentDownloads = max(ValidationConstants.minConcurrentDownloads, min(ValidationConstants.maxConcurrentDownloads, maxConcurrentDownloads))  // Clamp 1-10
        self.defaultUpdateFrequency = defaultUpdateFrequency
        
        // Validate retention policy values
        switch retentionPolicy {
        case .keepLatest(let count) where count < 1:
            self.retentionPolicy = .keepLatest(1)
        case .deleteAfterDays(let days) where days < ValidationConstants.minRetentionDays:
            self.retentionPolicy = .deleteAfterDays(ValidationConstants.minRetentionDays)
        case .deleteAfterDays(let days) where days > ValidationConstants.maxRetentionDays:
            self.retentionPolicy = .deleteAfterDays(ValidationConstants.maxRetentionDays)
        default:
            self.retentionPolicy = retentionPolicy
        }
    }
    
    /// Default download settings
    public static let `default` = DownloadSettings(
        autoDownloadEnabled: false,
        wifiOnly: true,
        maxConcurrentDownloads: 3,
        retentionPolicy: .keepLatest(5),
        defaultUpdateFrequency: .every6Hours
    )
}

/// Per-podcast download overrides
public struct PodcastDownloadSettings: Codable, Equatable, Sendable {
    public let podcastId: String
    public let autoDownloadEnabled: Bool?
    public let wifiOnly: Bool?
    public let retentionPolicy: RetentionPolicy?
    public let updateFrequency: UpdateFrequency?
    
    public init(
        podcastId: String,
        autoDownloadEnabled: Bool?,
        wifiOnly: Bool?,
        retentionPolicy: RetentionPolicy?,
        updateFrequency: UpdateFrequency? = nil
    ) {
        self.podcastId = podcastId
        self.autoDownloadEnabled = autoDownloadEnabled
        self.wifiOnly = wifiOnly
        self.retentionPolicy = retentionPolicy
        self.updateFrequency = updateFrequency
    }
}

/// Notification preferences
public struct NotificationSettings: Codable, Equatable, Sendable {
    public let newEpisodeNotifications: Bool
    public let downloadCompleteNotifications: Bool
    public let soundEnabled: Bool
    public let customSounds: [String: String]  // podcastId -> sound name
    
    public init(
        newEpisodeNotifications: Bool,
        downloadCompleteNotifications: Bool,
        soundEnabled: Bool,
        customSounds: [String: String]
    ) {
        self.newEpisodeNotifications = newEpisodeNotifications
        self.downloadCompleteNotifications = downloadCompleteNotifications
        self.soundEnabled = soundEnabled
        self.customSounds = customSounds
    }
    
    /// Default notification settings
    public static let `default` = NotificationSettings(
        newEpisodeNotifications: true,
        downloadCompleteNotifications: false,
        soundEnabled: true,
        customSounds: [:]
    )
}

/// Per-podcast playback overrides (extends existing PlaybackSettings concept)
public struct PodcastPlaybackSettings: Codable, Equatable, Sendable {
    public let podcastId: String
    public let playbackSpeed: Float?
    public let skipForwardInterval: TimeInterval?
    public let skipBackwardInterval: TimeInterval?
    public let introSkipDuration: TimeInterval?
    public let outroSkipDuration: TimeInterval?
    
    public init(
        podcastId: String,
        playbackSpeed: Float? = nil,
        skipForwardInterval: TimeInterval? = nil,
        skipBackwardInterval: TimeInterval? = nil,
        introSkipDuration: TimeInterval? = nil,
        outroSkipDuration: TimeInterval? = nil
    ) {
        self.podcastId = podcastId
        self.playbackSpeed = playbackSpeed.map { max(ValidationConstants.minPlaybackSpeed, min(ValidationConstants.maxPlaybackSpeed, $0)) }  // Clamp if not nil
        self.skipForwardInterval = skipForwardInterval.map { max(ValidationConstants.minSkipInterval, min(ValidationConstants.maxSkipInterval, $0)) }  // Clamp if not nil
        self.skipBackwardInterval = skipBackwardInterval.map { max(ValidationConstants.minSkipInterval, min(ValidationConstants.maxSkipInterval, $0)) }  // Clamp if not nil
        self.introSkipDuration = introSkipDuration.map { max(0, $0) }  // Ensure non-negative
        self.outroSkipDuration = outroSkipDuration.map { max(0, $0) }  // Ensure non-negative
    }
}
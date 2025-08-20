@preconcurrency import Foundation

/// Global download settings
public struct DownloadSettings: Codable, Equatable, Sendable {
    public var autoDownloadEnabled: Bool
    public var downloadQuality: AudioQuality
    public var downloadOnWiFiOnly: Bool
    public var maxSimultaneousDownloads: Int
    public var deleteAfterDays: Int?
    public var retentionPolicy: RetentionPolicy?
    public var defaultUpdateFrequency: UpdateFrequency?
    
    public init(
        autoDownloadEnabled: Bool = false,
        downloadQuality: AudioQuality = .standard,
        downloadOnWiFiOnly: Bool = true,
        maxSimultaneousDownloads: Int = 3,
        deleteAfterDays: Int? = nil,
        retentionPolicy: RetentionPolicy? = nil,
        defaultUpdateFrequency: UpdateFrequency? = nil
    ) {
        self.autoDownloadEnabled = autoDownloadEnabled
        self.downloadQuality = downloadQuality
        self.downloadOnWiFiOnly = downloadOnWiFiOnly
        self.maxSimultaneousDownloads = maxSimultaneousDownloads
        self.deleteAfterDays = deleteAfterDays
        self.retentionPolicy = retentionPolicy
        self.defaultUpdateFrequency = defaultUpdateFrequency
    }
    
    public static let `default` = DownloadSettings()
}

/// Per-podcast download settings that override global settings
public struct PodcastDownloadSettings: Codable, Equatable, Sendable {
    public var podcastId: String
    public var autoDownloadEnabled: Bool?
    public var downloadQuality: AudioQuality?
    public var maxEpisodesToKeep: Int?
    
    public init(
        podcastId: String,
        autoDownloadEnabled: Bool? = nil,
        downloadQuality: AudioQuality? = nil,
        maxEpisodesToKeep: Int? = nil
    ) {
        self.podcastId = podcastId
        self.autoDownloadEnabled = autoDownloadEnabled
        self.downloadQuality = downloadQuality
        self.maxEpisodesToKeep = maxEpisodesToKeep
    }
}

/// Audio quality options for downloads
public enum AudioQuality: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case standard = "standard" 
    case high = "high"
    
    public var displayName: String {
        switch self {
        case .low: return "Low Quality"
        case .standard: return "Standard Quality"
        case .high: return "High Quality"
        }
    }
}

public enum RetentionPolicy: String, Codable, CaseIterable, Sendable {
    case keepAll
    case keepLatest
    case deleteAfterDays
}

public enum UpdateFrequency: String, Codable, CaseIterable, Sendable {
    case hourly
    case daily
    case weekly
    case manual
}

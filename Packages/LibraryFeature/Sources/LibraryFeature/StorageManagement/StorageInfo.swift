import Foundation

/// Storage information for a single podcast
public struct PodcastStorageInfo: Identifiable, Sendable {
    public let id: String
    public let podcastTitle: String
    public let episodeCount: Int
    public let totalBytes: Int64

    public init(id: String, podcastTitle: String, episodeCount: Int, totalBytes: Int64) {
        self.id = id
        self.podcastTitle = podcastTitle
        self.episodeCount = episodeCount
        self.totalBytes = totalBytes
    }

    /// Human-readable storage size (e.g., "25.3 MB", "1.2 GB")
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    /// Storage size in megabytes (for calculations)
    public var megabytes: Double {
        Double(totalBytes) / 1_048_576.0 // 1024 * 1024
    }
}

/// Overall storage statistics for all downloads
public struct StorageStatistics: Sendable {
    public let totalBytes: Int64
    public let totalEpisodes: Int
    public let podcastBreakdown: [PodcastStorageInfo]

    public init(totalBytes: Int64, totalEpisodes: Int, podcastBreakdown: [PodcastStorageInfo]) {
        self.totalBytes = totalBytes
        self.totalEpisodes = totalEpisodes
        self.podcastBreakdown = podcastBreakdown
    }

    /// Human-readable total storage size
    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    /// Total storage in megabytes
    public var totalMegabytes: Double {
        Double(totalBytes) / 1_048_576.0
    }

    /// Total storage in gigabytes
    public var totalGigabytes: Double {
        Double(totalBytes) / 1_073_741_824.0 // 1024 * 1024 * 1024
    }

    /// Empty state (no downloads)
    public static var empty: StorageStatistics {
        StorageStatistics(totalBytes: 0, totalEpisodes: 0, podcastBreakdown: [])
    }
}

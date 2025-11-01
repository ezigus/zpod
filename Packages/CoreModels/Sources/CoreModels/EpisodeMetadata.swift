import Foundation

/// Extended metadata for podcast episodes
public struct EpisodeMetadata: Codable, Equatable, Sendable {
    /// Episode identifier this metadata belongs to
    public let episodeId: String
    
    /// File size in bytes (if known)
    public let fileSizeBytes: Int64?
    
    /// Audio bitrate in kbps (if known)
    public let bitrate: Int?
    
    /// Audio format (e.g., "mp3", "m4a", "ogg")
    public let format: String?
    
    /// Audio codec (e.g., "MPEG Layer 3", "AAC")
    public let codec: String?
    
    /// Sample rate in Hz (e.g., 44100, 48000)
    public let sampleRate: Int?
    
    /// Number of audio channels (1 = mono, 2 = stereo)
    public let channels: Int?
    
    /// Average community rating (1.0 - 5.0)
    public let communityRating: Double?
    
    /// Number of community ratings captured
    public let ratingsCount: Int?

    public init(
        episodeId: String,
        fileSizeBytes: Int64? = nil,
        bitrate: Int? = nil,
        format: String? = nil,
        codec: String? = nil,
        sampleRate: Int? = nil,
        channels: Int? = nil,
        communityRating: Double? = nil,
        ratingsCount: Int? = nil
    ) {
        self.episodeId = episodeId
        self.fileSizeBytes = fileSizeBytes
        self.bitrate = bitrate
        self.format = format
        self.codec = codec
        self.sampleRate = sampleRate
        self.channels = channels
        self.communityRating = communityRating
        self.ratingsCount = ratingsCount
    }
}

// MARK: - Computed Properties

public extension EpisodeMetadata {
    /// Formatted file size string (e.g., "45.2 MB")
    var formattedFileSize: String? {
        guard let bytes = fileSizeBytes else { return nil }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Formatted bitrate string (e.g., "128 kbps")
    var formattedBitrate: String? {
        guard let bitrate = bitrate else { return nil }
        return "\(bitrate) kbps"
    }
    
    /// Formatted sample rate string (e.g., "44.1 kHz")
    var formattedSampleRate: String? {
        guard let sampleRate = sampleRate else { return nil }
        let khz = Double(sampleRate) / 1000.0
        return String(format: "%.1f kHz", khz)
    }
    
    /// Audio quality description (e.g., "Stereo", "Mono")
    var channelDescription: String? {
        guard let channels = channels else { return nil }
        switch channels {
        case 1: return "Mono"
        case 2: return "Stereo"
        default: return "\(channels) channels"
        }
    }
    
    /// Formatted community rating with star indicator and ratings count
    var formattedCommunityRating: String? {
        guard let communityRating = communityRating else { return nil }
        let roundedRating = String(format: "%.1f★", communityRating)
        if let ratingsCount = ratingsCount {
            return "\(roundedRating) (\(ratingsCount))"
        }
        return roundedRating
    }
}

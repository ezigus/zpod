import Foundation

/// A bookmark within a podcast episode at a specific timestamp
public struct EpisodeBookmark: Codable, Equatable, Sendable, Identifiable {
    /// Unique identifier for the bookmark
    public let id: String
    
    /// Episode identifier this bookmark belongs to
    public let episodeId: String
    
    /// Timestamp in the episode (in seconds)
    public let timestamp: TimeInterval
    
    /// Custom label for the bookmark
    public var label: String
    
    /// When the bookmark was created
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        episodeId: String,
        timestamp: TimeInterval,
        label: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.episodeId = episodeId
        self.timestamp = max(0, timestamp) // Ensure non-negative
        self.label = label
        self.createdAt = createdAt
    }
    
    /// Create a new bookmark with updated label
    public func withLabel(_ newLabel: String) -> EpisodeBookmark {
        var copy = self
        copy.label = newLabel
        return copy
    }
}

// MARK: - Helpers

public extension EpisodeBookmark {
    /// Formatted timestamp string (e.g., "12:34" or "1:23:45")
    var formattedTimestamp: String {
        let totalSeconds = Int(timestamp)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Default label if none provided
    var displayLabel: String {
        label.isEmpty ? "Bookmark at \(formattedTimestamp)" : label
    }
}

// MARK: - Sorting

public extension Array where Element == EpisodeBookmark {
    /// Sort bookmarks by timestamp (chronological order)
    func sortedByTimestamp() -> [EpisodeBookmark] {
        sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Sort bookmarks by creation date (newest first)
    func sortedByCreationDate() -> [EpisodeBookmark] {
        sorted { $0.createdAt > $1.createdAt }
    }
}

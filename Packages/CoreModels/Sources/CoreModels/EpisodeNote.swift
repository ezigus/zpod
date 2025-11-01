import Foundation

/// A personal note attached to a podcast episode
public struct EpisodeNote: Codable, Equatable, Sendable, Identifiable {
    /// Unique identifier for the note
    public let id: String
    
    /// Episode identifier this note belongs to
    public let episodeId: String
    
    /// Note text content
    public var text: String
    
    /// Tags for organizing notes
    public var tags: [String]
    
    /// When the note was created
    public let createdAt: Date
    
    /// When the note was last modified
    public var modifiedAt: Date
    
    /// Optional timestamp reference in the episode (in seconds)
    public var timestamp: TimeInterval?
    
    public init(
        id: String = UUID().uuidString,
        episodeId: String,
        text: String,
        tags: [String] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        timestamp: TimeInterval? = nil
    ) {
        self.id = id
        self.episodeId = episodeId
        self.text = text
        self.tags = tags
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.timestamp = timestamp
    }
    
    /// Create a new note with updated text
    public func withText(_ newText: String) -> EpisodeNote {
        var copy = self
        copy.text = newText
        copy.modifiedAt = Date()
        return copy
    }
    
    /// Create a new note with updated tags
    public func withTags(_ newTags: [String]) -> EpisodeNote {
        var copy = self
        copy.tags = newTags
        copy.modifiedAt = Date()
        return copy
    }
    
    /// Create a new note with an added tag
    public func addingTag(_ tag: String) -> EpisodeNote {
        guard !tags.contains(tag) else { return self }
        var copy = self
        copy.tags.append(tag)
        copy.modifiedAt = Date()
        return copy
    }
    
    /// Create a new note with a removed tag
    public func removingTag(_ tag: String) -> EpisodeNote {
        var copy = self
        copy.tags.removeAll { $0 == tag }
        copy.modifiedAt = Date()
        return copy
    }
}

// MARK: - Helpers

public extension EpisodeNote {
    /// Formatted timestamp string (e.g., "12:34")
    var formattedTimestamp: String? {
        guard let timestamp = timestamp else { return nil }
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Whether this note has any tags
    var hasTags: Bool {
        !tags.isEmpty
    }
    
    /// Truncated preview of note text
    func preview(maxLength: Int = 100) -> String {
        guard text.count > maxLength else { return text }
        let index = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<index]) + "..."
    }
}

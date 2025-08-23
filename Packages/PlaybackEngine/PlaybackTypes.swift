import Foundation
import CoreModels

// MARK: - PlaybackSettings

/// Settings for audio playback behavior
public class PlaybackSettings {
    public var defaultSpeed: Float = 1.0
    public var skipForwardInterval: TimeInterval = 30
    public var skipBackwardInterval: TimeInterval = 15
    public var enableCrossfade: Bool = false
    public var crossfadeDuration: TimeInterval = 3.0
    
    public init() {}
}

// MARK: - Chapter Support

/// Represents a chapter in an audio episode
public struct Chapter: Codable, Sendable {
    public let title: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let artworkURL: URL?
    
    public init(title: String, startTime: TimeInterval, endTime: TimeInterval, artworkURL: URL? = nil) {
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.artworkURL = artworkURL
    }
}

/// Protocol for parsing chapters from episode metadata
public protocol ChapterParser: Sendable {
    func parseChapters(from metadata: [String: Any]) -> [Chapter]
}

/// Basic implementation of chapter parser
public struct BasicChapterParser: ChapterParser {
    public init() {}
    
    public func parseChapters(from metadata: [String: Any]) -> [Chapter] {
        // Basic implementation - would parse from actual metadata in real app
        return []
    }
}
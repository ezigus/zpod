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

// Chapter is now imported from CoreModels

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
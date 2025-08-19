import Foundation

/// Represents a chapter within a podcast episode
public struct Chapter: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier for the chapter
    public let id: String
    
    /// Chapter title
    public let title: String
    
    /// Start time of the chapter in seconds
    public let startTime: TimeInterval
    
    /// Optional end time of the chapter in seconds
    public let endTime: TimeInterval?
    
    /// Optional chapter artwork URL
    public let artworkURL: URL?
    
    /// Optional chapter link/URL
    public let linkURL: URL?
    
    public init(
        id: String,
        title: String,
        startTime: TimeInterval,
        endTime: TimeInterval? = nil,
        artworkURL: URL? = nil,
        linkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.startTime = max(0, startTime)
        self.endTime = endTime.map { max(startTime, $0) }
        self.artworkURL = artworkURL
        self.linkURL = linkURL
    }
}

/// Protocol for parsing chapter information from episode metadata
public protocol ChapterParser {
    /// Parse chapters from episode metadata
    func parseChapters(from metadata: [String: Any]) -> [Chapter]
}

/// Basic chapter parser implementation
public final class BasicChapterParser: ChapterParser {
    public init() {}
    
    public func parseChapters(from metadata: [String: Any]) -> [Chapter] {
        // Look for common chapter metadata formats
        var chapters: [Chapter] = []
        
        // Check for AVMetadata chapters (common in MP3/M4A files)
        if let avChapters = metadata["chapters"] as? [[String: Any]] {
            for (index, chapterData) in avChapters.enumerated() {
                if let title = chapterData["title"] as? String,
                   let startTime = chapterData["start"] as? TimeInterval {
                    let chapter = Chapter(
                        id: "chapter_\(index)",
                        title: title,
                        startTime: startTime,
                        endTime: chapterData["end"] as? TimeInterval,
                        artworkURL: (chapterData["artwork"] as? String).flatMap(URL.init(string:)),
                        linkURL: (chapterData["url"] as? String).flatMap(URL.init(string:))
                    )
                    chapters.append(chapter)
                }
            }
        }
        
        // Check for podcast namespace chapters (newer standard)
        if let podcastChapters = metadata["podcast:chapters"] as? [[String: Any]] {
            for (index, chapterData) in podcastChapters.enumerated() {
                if let title = chapterData["title"] as? String,
                   let startTimeString = chapterData["startTime"] as? String,
                   let startTime = parseTimeString(startTimeString) {
                    let chapter = Chapter(
                        id: "podcast_chapter_\(index)",
                        title: title,
                        startTime: startTime,
                        endTime: (chapterData["endTime"] as? String).flatMap(parseTimeString),
                        artworkURL: (chapterData["img"] as? String).flatMap(URL.init(string:)),
                        linkURL: (chapterData["url"] as? String).flatMap(URL.init(string:))
                    )
                    chapters.append(chapter)
                }
            }
        }
        
        return chapters.sorted { $0.startTime < $1.startTime }
    }
    
    private func parseTimeString(_ timeString: String) -> TimeInterval? {
        // Parse time formats like "00:05:30" or "5:30" or "330"
        let components = timeString.components(separatedBy: ":")
        
        switch components.count {
        case 1:
            // Just seconds
            return Double(components[0])
        case 2:
            // MM:SS
            guard let minutes = Double(components[0]),
                  let seconds = Double(components[1]) else { return nil }
            return minutes * 60 + seconds
        case 3:
            // HH:MM:SS
            guard let hours = Double(components[0]),
                  let minutes = Double(components[1]),
                  let seconds = Double(components[2]) else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        default:
            return nil
        }
    }
}

import Foundation

/// A transcript segment with text and timestamp information
public struct TranscriptSegment: Codable, Equatable, Sendable, Identifiable {
    /// Unique identifier for the segment
    public let id: String
    
    /// Start time of the segment in seconds
    public let startTime: TimeInterval
    
    /// End time of the segment in seconds (optional)
    public let endTime: TimeInterval?
    
    /// Transcript text for this segment
    public let text: String
    
    public init(
        id: String = UUID().uuidString,
        startTime: TimeInterval,
        endTime: TimeInterval? = nil,
        text: String
    ) {
        self.id = id
        self.startTime = max(0, startTime)
        self.endTime = endTime.map { max(startTime, $0) }
        self.text = text
    }
}

/// Episode transcript with searchable text segments
public struct EpisodeTranscript: Codable, Equatable, Sendable {
    /// Episode identifier this transcript belongs to
    public let episodeId: String
    
    /// Transcript segments with timestamps
    public let segments: [TranscriptSegment]
    
    /// Language code (e.g., "en", "es")
    public let language: String?
    
    /// When the transcript was last updated
    public let updatedAt: Date
    
    public init(
        episodeId: String,
        segments: [TranscriptSegment],
        language: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.episodeId = episodeId
        self.segments = segments
        self.language = language
        self.updatedAt = updatedAt
    }
}

// MARK: - Transcript Helpers

public extension EpisodeTranscript {
    /// Full transcript text (all segments concatenated)
    var fullText: String {
        segments.map { $0.text }.joined(separator: " ")
    }
    
    /// Search for text in transcript and return matching segments
    func search(_ query: String) -> [TranscriptSegment] {
        guard !query.isEmpty else { return [] }
        let lowercasedQuery = query.lowercased()
        
        return segments.filter { segment in
            segment.text.lowercased().contains(lowercasedQuery)
        }
    }
    
    /// Find segment at a specific timestamp
    func segment(at timestamp: TimeInterval) -> TranscriptSegment? {
        segments.last { segment in
            segment.startTime <= timestamp &&
            (segment.endTime == nil || segment.endTime! > timestamp)
        }
    }
    
    /// Get segments in a time range
    func segments(in range: ClosedRange<TimeInterval>) -> [TranscriptSegment] {
        segments.filter { segment in
            let start = segment.startTime
            let end = segment.endTime ?? (segment.startTime + 10) // Assume 10s if no end
            
            // Segment overlaps with range
            return (start >= range.lowerBound && start <= range.upperBound) ||
                   (end >= range.lowerBound && end <= range.upperBound) ||
                   (start <= range.lowerBound && end >= range.upperBound)
        }
    }
}

// MARK: - Transcript Search Result

public struct TranscriptSearchResult: Identifiable, Sendable {
    public let id: String
    public let segment: TranscriptSegment
    public let matchRanges: [Range<String.Index>]
    
    public init(segment: TranscriptSegment, matchRanges: [Range<String.Index>]) {
        self.id = segment.id
        self.segment = segment
        self.matchRanges = matchRanges
    }
}

// MARK: - Enhanced Search

public extension EpisodeTranscript {
    /// Advanced search returning results with match positions
    func searchWithRanges(_ query: String) -> [TranscriptSearchResult] {
        guard !query.isEmpty else { return [] }
        let lowercasedQuery = query.lowercased()
        
        return segments.compactMap { segment in
            let text = segment.text
            let lowercasedText = text.lowercased()
            var ranges: [Range<String.Index>] = []
            
            var searchStartIndex = lowercasedText.startIndex
            while searchStartIndex < lowercasedText.endIndex,
                  let range = lowercasedText.range(of: lowercasedQuery, range: searchStartIndex..<lowercasedText.endIndex) {
                ranges.append(range)
                searchStartIndex = range.upperBound
            }
            
            guard !ranges.isEmpty else { return nil }
            return TranscriptSearchResult(segment: segment, matchRanges: ranges)
        }
    }
}

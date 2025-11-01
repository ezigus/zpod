import XCTest
@testable import CoreModels

/// Unit tests for episode annotation models (EpisodeMetadata, EpisodeNote, EpisodeBookmark, EpisodeTranscript)
final class EpisodeAnnotationModelsTests: XCTestCase {
    
    // MARK: - EpisodeMetadata Tests
    
    func testEpisodeMetadataInitialization() {
        // Given: Metadata parameters
        let episodeId = "episode-123"
        let fileSize: Int64 = 45_000_000 // 45 MB
        let bitrate = 128
        let format = "mp3"
        
        // When: Creating metadata
        let metadata = EpisodeMetadata(
            episodeId: episodeId,
            fileSizeBytes: fileSize,
            bitrate: bitrate,
            format: format
        )
        
        // Then: Properties should be set correctly
        XCTAssertEqual(metadata.episodeId, episodeId)
        XCTAssertEqual(metadata.fileSizeBytes, fileSize)
        XCTAssertEqual(metadata.bitrate, bitrate)
        XCTAssertEqual(metadata.format, format)
    }
    
    func testEpisodeMetadataFormattedFileSize() {
        // Given: Metadata with file size
        let metadata = EpisodeMetadata(
            episodeId: "episode-1",
            fileSizeBytes: 45_678_901
        )
        
        // When: Accessing formatted file size
        let formatted = metadata.formattedFileSize
        
        // Then: Should be human-readable
        XCTAssertNotNil(formatted)
        XCTAssertTrue(formatted!.contains("MB") || formatted!.contains("GB"))
    }
    
    func testEpisodeMetadataFormattedBitrate() {
        // Given: Metadata with bitrate
        let metadata = EpisodeMetadata(
            episodeId: "episode-1",
            bitrate: 192
        )
        
        // When: Accessing formatted bitrate
        let formatted = metadata.formattedBitrate
        
        // Then: Should include kbps
        XCTAssertEqual(formatted, "192 kbps")
    }
    
    func testEpisodeMetadataChannelDescription() {
        // Given: Metadata with stereo channels
        let stereo = EpisodeMetadata(episodeId: "episode-1", channels: 2)
        let mono = EpisodeMetadata(episodeId: "episode-2", channels: 1)
        
        // When: Accessing channel description
        // Then: Should return appropriate labels
        XCTAssertEqual(stereo.channelDescription, "Stereo")
        XCTAssertEqual(mono.channelDescription, "Mono")
    }
    
    // MARK: - EpisodeNote Tests
    
    func testEpisodeNoteInitialization() {
        // Given: Note parameters
        let episodeId = "episode-123"
        let text = "Great discussion about Swift concurrency!"
        let tags = ["swift", "concurrency"]
        
        // When: Creating a note
        let note = EpisodeNote(
            episodeId: episodeId,
            text: text,
            tags: tags
        )
        
        // Then: Properties should be set
        XCTAssertEqual(note.episodeId, episodeId)
        XCTAssertEqual(note.text, text)
        XCTAssertEqual(note.tags, tags)
        XCTAssertNotNil(note.id)
        XCTAssertNotNil(note.createdAt)
    }
    
    func testEpisodeNoteWithText() {
        // Given: An existing note
        let original = EpisodeNote(
            episodeId: "episode-1",
            text: "Original text"
        )
        
        // When: Updating text
        let updated = original.withText("Updated text")
        
        // Then: Text should change, modifiedAt should update
        XCTAssertEqual(updated.text, "Updated text")
        XCTAssertGreaterThanOrEqual(updated.modifiedAt, original.modifiedAt)
    }
    
    func testEpisodeNoteAddingTag() {
        // Given: A note without tags
        let note = EpisodeNote(
            episodeId: "episode-1",
            text: "Test note"
        )
        
        // When: Adding a tag
        let withTag = note.addingTag("important")
        
        // Then: Tag should be added
        XCTAssertTrue(withTag.tags.contains("important"))
        XCTAssertEqual(withTag.tags.count, 1)
    }
    
    func testEpisodeNoteRemovingTag() {
        // Given: A note with tags
        let note = EpisodeNote(
            episodeId: "episode-1",
            text: "Test note",
            tags: ["tag1", "tag2", "tag3"]
        )
        
        // When: Removing a tag
        let withoutTag = note.removingTag("tag2")
        
        // Then: Tag should be removed
        XCTAssertFalse(withoutTag.tags.contains("tag2"))
        XCTAssertEqual(withoutTag.tags.count, 2)
    }
    
    func testEpisodeNoteFormattedTimestamp() {
        // Given: A note with timestamp
        let note = EpisodeNote(
            episodeId: "episode-1",
            text: "Test note",
            timestamp: 754.0 // 12:34
        )
        
        // When: Accessing formatted timestamp
        let formatted = note.formattedTimestamp
        
        // Then: Should be formatted as MM:SS
        XCTAssertEqual(formatted, "12:34")
    }
    
    func testEpisodeNotePreview() {
        // Given: A long note
        let longText = String(repeating: "A", count: 200)
        let note = EpisodeNote(
            episodeId: "episode-1",
            text: longText
        )
        
        // When: Getting preview
        let preview = note.preview(maxLength: 50)
        
        // Then: Should be truncated
        XCTAssertLessThanOrEqual(preview.count, 53) // 50 + "..."
        XCTAssertTrue(preview.hasSuffix("..."))
    }
    
    // MARK: - EpisodeBookmark Tests
    
    func testEpisodeBookmarkInitialization() {
        // Given: Bookmark parameters
        let episodeId = "episode-123"
        let timestamp: TimeInterval = 300.0 // 5:00
        let label = "Important section"
        
        // When: Creating a bookmark
        let bookmark = EpisodeBookmark(
            episodeId: episodeId,
            timestamp: timestamp,
            label: label
        )
        
        // Then: Properties should be set
        XCTAssertEqual(bookmark.episodeId, episodeId)
        XCTAssertEqual(bookmark.timestamp, timestamp)
        XCTAssertEqual(bookmark.label, label)
        XCTAssertNotNil(bookmark.id)
    }
    
    func testEpisodeBookmarkNegativeTimestampClamped() {
        // Given: A negative timestamp
        let bookmark = EpisodeBookmark(
            episodeId: "episode-1",
            timestamp: -10.0
        )
        
        // When: Accessing timestamp
        // Then: Should be clamped to 0
        XCTAssertEqual(bookmark.timestamp, 0.0)
    }
    
    func testEpisodeBookmarkFormattedTimestamp() {
        // Given: Bookmarks at different times
        let short = EpisodeBookmark(episodeId: "episode-1", timestamp: 75.0) // 1:15
        let long = EpisodeBookmark(episodeId: "episode-1", timestamp: 3661.0) // 1:01:01
        
        // When: Accessing formatted timestamp
        // Then: Should format appropriately
        XCTAssertEqual(short.formattedTimestamp, "1:15")
        XCTAssertEqual(long.formattedTimestamp, "1:01:01")
    }
    
    func testEpisodeBookmarkDisplayLabel() {
        // Given: Bookmarks with and without labels
        let withLabel = EpisodeBookmark(
            episodeId: "episode-1",
            timestamp: 100.0,
            label: "Custom label"
        )
        let withoutLabel = EpisodeBookmark(
            episodeId: "episode-1",
            timestamp: 100.0
        )
        
        // When: Accessing display label
        // Then: Should use custom label or generate default
        XCTAssertEqual(withLabel.displayLabel, "Custom label")
        XCTAssertTrue(withoutLabel.displayLabel.contains("Bookmark at"))
    }
    
    func testBookmarksSortedByTimestamp() {
        // Given: Unsorted bookmarks
        let bookmarks = [
            EpisodeBookmark(episodeId: "episode-1", timestamp: 300.0),
            EpisodeBookmark(episodeId: "episode-1", timestamp: 100.0),
            EpisodeBookmark(episodeId: "episode-1", timestamp: 200.0)
        ]
        
        // When: Sorting by timestamp
        let sorted = bookmarks.sortedByTimestamp()
        
        // Then: Should be in chronological order
        XCTAssertEqual(sorted[0].timestamp, 100.0)
        XCTAssertEqual(sorted[1].timestamp, 200.0)
        XCTAssertEqual(sorted[2].timestamp, 300.0)
    }
    
    // MARK: - EpisodeTranscript Tests
    
    func testTranscriptSegmentInitialization() {
        // Given: Segment parameters
        let startTime: TimeInterval = 10.0
        let endTime: TimeInterval = 20.0
        let text = "Welcome to the podcast"
        
        // When: Creating a segment
        let segment = TranscriptSegment(
            startTime: startTime,
            endTime: endTime,
            text: text
        )
        
        // Then: Properties should be set
        XCTAssertEqual(segment.startTime, startTime)
        XCTAssertEqual(segment.endTime, endTime)
        XCTAssertEqual(segment.text, text)
    }
    
    func testEpisodeTranscriptFullText() {
        // Given: A transcript with multiple segments
        let segments = [
            TranscriptSegment(startTime: 0, text: "Hello"),
            TranscriptSegment(startTime: 5, text: "world"),
            TranscriptSegment(startTime: 10, text: "!")
        ]
        let transcript = EpisodeTranscript(
            episodeId: "episode-1",
            segments: segments
        )
        
        // When: Accessing full text
        let fullText = transcript.fullText
        
        // Then: Should concatenate all segments
        XCTAssertEqual(fullText, "Hello world !")
    }
    
    func testTranscriptSearch() {
        // Given: A transcript with searchable content
        let segments = [
            TranscriptSegment(startTime: 0, text: "The Swift programming language"),
            TranscriptSegment(startTime: 10, text: "is great for iOS development"),
            TranscriptSegment(startTime: 20, text: "and also for server-side Swift")
        ]
        let transcript = EpisodeTranscript(
            episodeId: "episode-1",
            segments: segments
        )
        
        // When: Searching for "Swift"
        let results = transcript.search("Swift")
        
        // Then: Should find matching segments
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.text.contains("Swift programming") })
        XCTAssertTrue(results.contains { $0.text.contains("server-side Swift") })
    }
    
    func testTranscriptSearchCaseInsensitive() {
        // Given: A transcript
        let segment = TranscriptSegment(startTime: 0, text: "Swift Programming")
        let transcript = EpisodeTranscript(
            episodeId: "episode-1",
            segments: [segment]
        )
        
        // When: Searching with different case
        let results = transcript.search("swift")
        
        // Then: Should match case-insensitively
        XCTAssertEqual(results.count, 1)
    }
    
    func testTranscriptSegmentAtTimestamp() {
        // Given: A transcript with time-ordered segments
        let segments = [
            TranscriptSegment(startTime: 0, endTime: 10, text: "First"),
            TranscriptSegment(startTime: 10, endTime: 20, text: "Second"),
            TranscriptSegment(startTime: 20, endTime: 30, text: "Third")
        ]
        let transcript = EpisodeTranscript(
            episodeId: "episode-1",
            segments: segments
        )
        
        // When: Finding segment at specific times
        let at5 = transcript.segment(at: 5.0)
        let at15 = transcript.segment(at: 15.0)
        let at25 = transcript.segment(at: 25.0)
        
        // Then: Should return correct segments
        XCTAssertEqual(at5?.text, "First")
        XCTAssertEqual(at15?.text, "Second")
        XCTAssertEqual(at25?.text, "Third")
    }
    
    func testTranscriptSearchWithRanges() {
        // Given: A transcript
        let segment = TranscriptSegment(
            startTime: 0,
            text: "Swift is great and Swift is powerful"
        )
        let transcript = EpisodeTranscript(
            episodeId: "episode-1",
            segments: [segment]
        )
        
        // When: Searching with ranges
        let results = transcript.searchWithRanges("Swift")
        
        // Then: Should find multiple occurrences
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].matchRanges.count, 2) // Two occurrences of "Swift"
    }
}

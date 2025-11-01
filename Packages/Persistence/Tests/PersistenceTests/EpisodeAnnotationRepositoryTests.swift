import XCTest
@testable import Persistence
import CoreModels

final class EpisodeAnnotationRepositoryTests: XCTestCase {
    private var repository: UserDefaultsEpisodeAnnotationRepository!
    private var harness: UserDefaultsTestHarness!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        harness = makeUserDefaultsHarness(prefix: "annotation")
        repository = UserDefaultsEpisodeAnnotationRepository(suiteName: harness.suiteName)
    }
    
    override func tearDownWithError() throws {
        repository = nil
        harness = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Metadata Tests
    
    func testSaveAndLoadMetadata() async throws {
        // Given: Episode metadata
        let metadata = EpisodeMetadata(
            episodeId: "episode-123",
            fileSizeBytes: 45_000_000,
            bitrate: 128,
            format: "mp3"
        )
        
        // When: Saving metadata
        try await repository.saveMetadata(metadata)
        
        // Then: Should be able to load it
        let loaded = try await repository.loadMetadata(for: "episode-123")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.episodeId, "episode-123")
        XCTAssertEqual(loaded?.fileSizeBytes, 45_000_000)
        XCTAssertEqual(loaded?.bitrate, 128)
        XCTAssertEqual(loaded?.format, "mp3")
    }
    
    func testLoadMetadata_NotFound() async throws {
        // When: Loading non-existent metadata
        let loaded = try await repository.loadMetadata(for: "nonexistent")
        
        // Then: Should return nil
        XCTAssertNil(loaded)
    }
    
    func testDeleteMetadata() async throws {
        // Given: Saved metadata
        let metadata = EpisodeMetadata(episodeId: "episode-123", bitrate: 128)
        try await repository.saveMetadata(metadata)
        
        // When: Deleting metadata
        try await repository.deleteMetadata(for: "episode-123")
        
        // Then: Should no longer exist
        let loaded = try await repository.loadMetadata(for: "episode-123")
        XCTAssertNil(loaded)
    }
    
    func testUpdateMetadata() async throws {
        // Given: Initial metadata
        let initial = EpisodeMetadata(episodeId: "episode-123", bitrate: 128)
        try await repository.saveMetadata(initial)
        
        // When: Updating with new values
        let updated = EpisodeMetadata(
            episodeId: "episode-123",
            bitrate: 192,
            format: "m4a"
        )
        try await repository.saveMetadata(updated)
        
        // Then: Should reflect updated values
        let loaded = try await repository.loadMetadata(for: "episode-123")
        XCTAssertEqual(loaded?.bitrate, 192)
        XCTAssertEqual(loaded?.format, "m4a")
    }
    
    // MARK: - Notes Tests
    
    func testSaveAndLoadNote() async throws {
        // Given: A note
        let note = EpisodeNote(
            episodeId: "episode-123",
            text: "Great episode about Swift!",
            tags: ["swift", "programming"]
        )
        
        // When: Saving note
        try await repository.saveNote(note)
        
        // Then: Should be able to load it
        let loaded = try await repository.loadNote(id: note.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.text, "Great episode about Swift!")
        XCTAssertEqual(loaded?.tags, ["swift", "programming"])
    }
    
    func testLoadNotesForEpisode() async throws {
        // Given: Multiple notes for an episode
        let note1 = EpisodeNote(episodeId: "episode-123", text: "First note")
        let note2 = EpisodeNote(episodeId: "episode-123", text: "Second note")
        let note3 = EpisodeNote(episodeId: "episode-456", text: "Other episode")
        
        try await repository.saveNote(note1)
        try await repository.saveNote(note2)
        try await repository.saveNote(note3)
        
        // When: Loading notes for specific episode
        let notes = try await repository.loadNotes(for: "episode-123")
        
        // Then: Should return only notes for that episode
        XCTAssertEqual(notes.count, 2)
        XCTAssertTrue(notes.contains { $0.text == "First note" })
        XCTAssertTrue(notes.contains { $0.text == "Second note" })
    }
    
    func testDeleteNote() async throws {
        // Given: A saved note
        let note = EpisodeNote(episodeId: "episode-123", text: "Test note")
        try await repository.saveNote(note)
        
        // When: Deleting note
        try await repository.deleteNote(id: note.id)
        
        // Then: Should no longer exist
        let loaded = try await repository.loadNote(id: note.id)
        XCTAssertNil(loaded)
        
        // And: Should be removed from episode index
        let notes = try await repository.loadNotes(for: "episode-123")
        XCTAssertTrue(notes.isEmpty)
    }
    
    func testDeleteAllNotesForEpisode() async throws {
        // Given: Multiple notes for an episode
        let note1 = EpisodeNote(episodeId: "episode-123", text: "First note")
        let note2 = EpisodeNote(episodeId: "episode-123", text: "Second note")
        
        try await repository.saveNote(note1)
        try await repository.saveNote(note2)
        
        // When: Deleting all notes for episode
        try await repository.deleteAllNotes(for: "episode-123")
        
        // Then: Should have no notes
        let notes = try await repository.loadNotes(for: "episode-123")
        XCTAssertTrue(notes.isEmpty)
    }
    
    func testUpdateNote() async throws {
        // Given: An existing note
        let original = EpisodeNote(
            episodeId: "episode-123",
            text: "Original text"
        )
        try await repository.saveNote(original)
        
        // When: Updating the note
        let updated = original.withText("Updated text")
        try await repository.saveNote(updated)
        
        // Then: Should reflect updated text
        let loaded = try await repository.loadNote(id: original.id)
        XCTAssertEqual(loaded?.text, "Updated text")
    }
    
    // MARK: - Bookmarks Tests
    
    func testSaveAndLoadBookmark() async throws {
        // Given: A bookmark
        let bookmark = EpisodeBookmark(
            episodeId: "episode-123",
            timestamp: 300.0,
            label: "Important section"
        )
        
        // When: Saving bookmark
        try await repository.saveBookmark(bookmark)
        
        // Then: Should be able to load it
        let loaded = try await repository.loadBookmark(id: bookmark.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.timestamp, 300.0)
        XCTAssertEqual(loaded?.label, "Important section")
    }
    
    func testLoadBookmarksForEpisode() async throws {
        // Given: Multiple bookmarks for an episode
        let bookmark1 = EpisodeBookmark(episodeId: "episode-123", timestamp: 100.0)
        let bookmark2 = EpisodeBookmark(episodeId: "episode-123", timestamp: 200.0)
        let bookmark3 = EpisodeBookmark(episodeId: "episode-456", timestamp: 150.0)
        
        try await repository.saveBookmark(bookmark1)
        try await repository.saveBookmark(bookmark2)
        try await repository.saveBookmark(bookmark3)
        
        // When: Loading bookmarks for specific episode
        let bookmarks = try await repository.loadBookmarks(for: "episode-123")
        
        // Then: Should return only bookmarks for that episode
        XCTAssertEqual(bookmarks.count, 2)
        XCTAssertTrue(bookmarks.contains { $0.timestamp == 100.0 })
        XCTAssertTrue(bookmarks.contains { $0.timestamp == 200.0 })
    }
    
    func testBookmarksSortedByTimestamp() async throws {
        // Given: Bookmarks saved in random order
        let bookmark1 = EpisodeBookmark(episodeId: "episode-123", timestamp: 300.0)
        let bookmark2 = EpisodeBookmark(episodeId: "episode-123", timestamp: 100.0)
        let bookmark3 = EpisodeBookmark(episodeId: "episode-123", timestamp: 200.0)
        
        try await repository.saveBookmark(bookmark1)
        try await repository.saveBookmark(bookmark2)
        try await repository.saveBookmark(bookmark3)
        
        // When: Loading bookmarks
        let bookmarks = try await repository.loadBookmarks(for: "episode-123")
        
        // Then: Should be sorted by timestamp
        XCTAssertEqual(bookmarks[0].timestamp, 100.0)
        XCTAssertEqual(bookmarks[1].timestamp, 200.0)
        XCTAssertEqual(bookmarks[2].timestamp, 300.0)
    }
    
    func testDeleteBookmark() async throws {
        // Given: A saved bookmark
        let bookmark = EpisodeBookmark(episodeId: "episode-123", timestamp: 150.0)
        try await repository.saveBookmark(bookmark)
        
        // When: Deleting bookmark
        try await repository.deleteBookmark(id: bookmark.id)
        
        // Then: Should no longer exist
        let loaded = try await repository.loadBookmark(id: bookmark.id)
        XCTAssertNil(loaded)
        
        // And: Should be removed from episode index
        let bookmarks = try await repository.loadBookmarks(for: "episode-123")
        XCTAssertTrue(bookmarks.isEmpty)
    }
    
    func testDeleteAllBookmarksForEpisode() async throws {
        // Given: Multiple bookmarks for an episode
        let bookmark1 = EpisodeBookmark(episodeId: "episode-123", timestamp: 100.0)
        let bookmark2 = EpisodeBookmark(episodeId: "episode-123", timestamp: 200.0)
        
        try await repository.saveBookmark(bookmark1)
        try await repository.saveBookmark(bookmark2)
        
        // When: Deleting all bookmarks for episode
        try await repository.deleteAllBookmarks(for: "episode-123")
        
        // Then: Should have no bookmarks
        let bookmarks = try await repository.loadBookmarks(for: "episode-123")
        XCTAssertTrue(bookmarks.isEmpty)
    }
    
    // MARK: - Transcript Tests
    
    func testSaveAndLoadTranscript() async throws {
        // Given: A transcript
        let segments = [
            TranscriptSegment(startTime: 0, text: "Hello"),
            TranscriptSegment(startTime: 5, text: "world")
        ]
        let transcript = EpisodeTranscript(
            episodeId: "episode-123",
            segments: segments,
            language: "en"
        )
        
        // When: Saving transcript
        try await repository.saveTranscript(transcript)
        
        // Then: Should be able to load it
        let loaded = try await repository.loadTranscript(for: "episode-123")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.segments.count, 2)
        XCTAssertEqual(loaded?.language, "en")
    }
    
    func testLoadTranscript_NotFound() async throws {
        // When: Loading non-existent transcript
        let loaded = try await repository.loadTranscript(for: "nonexistent")
        
        // Then: Should return nil
        XCTAssertNil(loaded)
    }
    
    func testDeleteTranscript() async throws {
        // Given: A saved transcript
        let transcript = EpisodeTranscript(
            episodeId: "episode-123",
            segments: []
        )
        try await repository.saveTranscript(transcript)
        
        // When: Deleting transcript
        try await repository.deleteTranscript(for: "episode-123")
        
        // Then: Should no longer exist
        let loaded = try await repository.loadTranscript(for: "episode-123")
        XCTAssertNil(loaded)
    }
    
    func testUpdateTranscript() async throws {
        // Given: Initial transcript
        let initial = EpisodeTranscript(
            episodeId: "episode-123",
            segments: [TranscriptSegment(startTime: 0, text: "Initial")]
        )
        try await repository.saveTranscript(initial)
        
        // When: Updating with new segments
        let updated = EpisodeTranscript(
            episodeId: "episode-123",
            segments: [
                TranscriptSegment(startTime: 0, text: "Updated"),
                TranscriptSegment(startTime: 5, text: "More text")
            ]
        )
        try await repository.saveTranscript(updated)
        
        // Then: Should reflect updated segments
        let loaded = try await repository.loadTranscript(for: "episode-123")
        XCTAssertEqual(loaded?.segments.count, 2)
        XCTAssertEqual(loaded?.segments.first?.text, "Updated")
    }
    
    // MARK: - Integration Tests
    
    func testMultipleAnnotationsForSameEpisode() async throws {
        // Given: Various annotations for same episode
        let metadata = EpisodeMetadata(episodeId: "episode-123", bitrate: 128)
        let note = EpisodeNote(episodeId: "episode-123", text: "Note")
        let bookmark = EpisodeBookmark(episodeId: "episode-123", timestamp: 100.0)
        let transcript = EpisodeTranscript(
            episodeId: "episode-123",
            segments: [TranscriptSegment(startTime: 0, text: "Text")]
        )
        
        // When: Saving all annotations
        try await repository.saveMetadata(metadata)
        try await repository.saveNote(note)
        try await repository.saveBookmark(bookmark)
        try await repository.saveTranscript(transcript)
        
        // Then: All should be loadable without hitting concurrency violations
        let loadedMetadata = try await repository.loadMetadata(for: "episode-123")
        let loadedNotes = try await repository.loadNotes(for: "episode-123")
        let loadedBookmarks = try await repository.loadBookmarks(for: "episode-123")
        let loadedTranscript = try await repository.loadTranscript(for: "episode-123")

        XCTAssertNotNil(loadedMetadata)
        XCTAssertEqual(loadedNotes.count, 1)
        XCTAssertEqual(loadedBookmarks.count, 1)
        XCTAssertNotNil(loadedTranscript)
    }
}

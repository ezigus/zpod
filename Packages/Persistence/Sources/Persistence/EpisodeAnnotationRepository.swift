import Foundation
import CoreModels
import SharedUtilities

// MARK: - Episode Annotation Repository Protocol

/// Protocol for managing episode annotations (notes, bookmarks, metadata, transcripts)
public protocol EpisodeAnnotationRepository: Sendable {
    // MARK: - Metadata
    
    /// Save episode metadata
    func saveMetadata(_ metadata: EpisodeMetadata) async throws
    
    /// Load episode metadata
    func loadMetadata(for episodeId: String) async throws -> EpisodeMetadata?
    
    /// Delete episode metadata
    func deleteMetadata(for episodeId: String) async throws
    
    // MARK: - Notes
    
    /// Save a note
    func saveNote(_ note: EpisodeNote) async throws
    
    /// Load all notes for an episode
    func loadNotes(for episodeId: String) async throws -> [EpisodeNote]
    
    /// Load a specific note by ID
    func loadNote(id: String) async throws -> EpisodeNote?
    
    /// Delete a note
    func deleteNote(id: String) async throws
    
    /// Delete all notes for an episode
    func deleteAllNotes(for episodeId: String) async throws
    
    // MARK: - Bookmarks
    
    /// Save a bookmark
    func saveBookmark(_ bookmark: EpisodeBookmark) async throws
    
    /// Load all bookmarks for an episode
    func loadBookmarks(for episodeId: String) async throws -> [EpisodeBookmark]
    
    /// Load a specific bookmark by ID
    func loadBookmark(id: String) async throws -> EpisodeBookmark?
    
    /// Delete a bookmark
    func deleteBookmark(id: String) async throws
    
    /// Delete all bookmarks for an episode
    func deleteAllBookmarks(for episodeId: String) async throws
    
    // MARK: - Transcripts
    
    /// Save episode transcript
    func saveTranscript(_ transcript: EpisodeTranscript) async throws
    
    /// Load episode transcript
    func loadTranscript(for episodeId: String) async throws -> EpisodeTranscript?
    
    /// Delete episode transcript
    func deleteTranscript(for episodeId: String) async throws
}

// MARK: - UserDefaults Implementation

public actor UserDefaultsEpisodeAnnotationRepository: EpisodeAnnotationRepository {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Storage keys
    private let metadataPrefix = "episode_metadata:"
    private let notePrefix = "episode_note:"
    private let notesIndexPrefix = "episode_notes_index:"
    private let bookmarkPrefix = "episode_bookmark:"
    private let bookmarksIndexPrefix = "episode_bookmarks_index:"
    private let transcriptPrefix = "episode_transcript:"
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    public init(suiteName: String) {
        if let suiteDefaults = UserDefaults(suiteName: suiteName) {
            self.userDefaults = suiteDefaults
        } else {
            self.userDefaults = .standard
        }
    }
    
    // MARK: - Metadata
    
    public func saveMetadata(_ metadata: EpisodeMetadata) async throws {
        let key = metadataPrefix + metadata.episodeId
        do {
            let data = try encoder.encode(metadata)
            userDefaults.set(data, forKey: key)
        } catch {
            throw SharedError.persistenceError("Failed to encode episode metadata: \(error)")
        }
    }
    
    public func loadMetadata(for episodeId: String) async throws -> EpisodeMetadata? {
        let key = metadataPrefix + episodeId
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try decoder.decode(EpisodeMetadata.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode episode metadata: \(error)")
        }
    }
    
    public func deleteMetadata(for episodeId: String) async throws {
        let key = metadataPrefix + episodeId
        userDefaults.removeObject(forKey: key)
    }
    
    // MARK: - Notes
    
    public func saveNote(_ note: EpisodeNote) async throws {
        // Save the note itself
        let noteKey = notePrefix + note.id
        do {
            let data = try encoder.encode(note)
            userDefaults.set(data, forKey: noteKey)
        } catch {
            throw SharedError.persistenceError("Failed to encode episode note: \(error)")
        }
        
        // Update the episode's notes index
        let indexKey = notesIndexPrefix + note.episodeId
        var noteIds = userDefaults.stringArray(forKey: indexKey) ?? []
        if !noteIds.contains(note.id) {
            noteIds.append(note.id)
            userDefaults.set(noteIds, forKey: indexKey)
        }
    }
    
    public func loadNotes(for episodeId: String) async throws -> [EpisodeNote] {
        let indexKey = notesIndexPrefix + episodeId
        guard let noteIds = userDefaults.stringArray(forKey: indexKey) else {
            return []
        }
        
        var notes: [EpisodeNote] = []
        for noteId in noteIds {
            if let note = try await loadNote(id: noteId) {
                notes.append(note)
            }
        }
        
        return notes.sorted { $0.createdAt > $1.createdAt } // Newest first
    }
    
    public func loadNote(id: String) async throws -> EpisodeNote? {
        let key = notePrefix + id
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try decoder.decode(EpisodeNote.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode episode note: \(error)")
        }
    }
    
    public func deleteNote(id: String) async throws {
        // Load the note to get episodeId
        guard let note = try await loadNote(id: id) else { return }
        
        // Remove from index
        let indexKey = notesIndexPrefix + note.episodeId
        if var noteIds = userDefaults.stringArray(forKey: indexKey) {
            noteIds.removeAll { $0 == id }
            userDefaults.set(noteIds, forKey: indexKey)
        }
        
        // Delete the note
        let noteKey = notePrefix + id
        userDefaults.removeObject(forKey: noteKey)
    }
    
    public func deleteAllNotes(for episodeId: String) async throws {
        let indexKey = notesIndexPrefix + episodeId
        guard let noteIds = userDefaults.stringArray(forKey: indexKey) else {
            return
        }
        
        // Delete all notes
        for noteId in noteIds {
            let noteKey = notePrefix + noteId
            userDefaults.removeObject(forKey: noteKey)
        }
        
        // Clear index
        userDefaults.removeObject(forKey: indexKey)
    }
    
    // MARK: - Bookmarks
    
    public func saveBookmark(_ bookmark: EpisodeBookmark) async throws {
        // Save the bookmark itself
        let bookmarkKey = bookmarkPrefix + bookmark.id
        do {
            let data = try encoder.encode(bookmark)
            userDefaults.set(data, forKey: bookmarkKey)
        } catch {
            throw SharedError.persistenceError("Failed to encode episode bookmark: \(error)")
        }
        
        // Update the episode's bookmarks index
        let indexKey = bookmarksIndexPrefix + bookmark.episodeId
        var bookmarkIds = userDefaults.stringArray(forKey: indexKey) ?? []
        if !bookmarkIds.contains(bookmark.id) {
            bookmarkIds.append(bookmark.id)
            userDefaults.set(bookmarkIds, forKey: indexKey)
        }
    }
    
    public func loadBookmarks(for episodeId: String) async throws -> [EpisodeBookmark] {
        let indexKey = bookmarksIndexPrefix + episodeId
        guard let bookmarkIds = userDefaults.stringArray(forKey: indexKey) else {
            return []
        }
        
        var bookmarks: [EpisodeBookmark] = []
        for bookmarkId in bookmarkIds {
            if let bookmark = try await loadBookmark(id: bookmarkId) {
                bookmarks.append(bookmark)
            }
        }
        
        return bookmarks.sortedByTimestamp() // Sort by timestamp
    }
    
    public func loadBookmark(id: String) async throws -> EpisodeBookmark? {
        let key = bookmarkPrefix + id
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try decoder.decode(EpisodeBookmark.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode episode bookmark: \(error)")
        }
    }
    
    public func deleteBookmark(id: String) async throws {
        // Load the bookmark to get episodeId
        guard let bookmark = try await loadBookmark(id: id) else { return }
        
        // Remove from index
        let indexKey = bookmarksIndexPrefix + bookmark.episodeId
        if var bookmarkIds = userDefaults.stringArray(forKey: indexKey) {
            bookmarkIds.removeAll { $0 == id }
            userDefaults.set(bookmarkIds, forKey: indexKey)
        }
        
        // Delete the bookmark
        let bookmarkKey = bookmarkPrefix + id
        userDefaults.removeObject(forKey: bookmarkKey)
    }
    
    public func deleteAllBookmarks(for episodeId: String) async throws {
        let indexKey = bookmarksIndexPrefix + episodeId
        guard let bookmarkIds = userDefaults.stringArray(forKey: indexKey) else {
            return
        }
        
        // Delete all bookmarks
        for bookmarkId in bookmarkIds {
            let bookmarkKey = bookmarkPrefix + bookmarkId
            userDefaults.removeObject(forKey: bookmarkKey)
        }
        
        // Clear index
        userDefaults.removeObject(forKey: indexKey)
    }
    
    // MARK: - Transcripts
    
    public func saveTranscript(_ transcript: EpisodeTranscript) async throws {
        let key = transcriptPrefix + transcript.episodeId
        do {
            let data = try encoder.encode(transcript)
            userDefaults.set(data, forKey: key)
        } catch {
            throw SharedError.persistenceError("Failed to encode episode transcript: \(error)")
        }
    }
    
    public func loadTranscript(for episodeId: String) async throws -> EpisodeTranscript? {
        let key = transcriptPrefix + episodeId
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        do {
            return try decoder.decode(EpisodeTranscript.self, from: data)
        } catch {
            throw SharedError.persistenceError("Failed to decode episode transcript: \(error)")
        }
    }
    
    public func deleteTranscript(for episodeId: String) async throws {
        let key = transcriptPrefix + episodeId
        userDefaults.removeObject(forKey: key)
    }
}

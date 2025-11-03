import Foundation
import CoreModels
import Persistence
import XCTest

@testable import PlayerFeature

@MainActor
final class EpisodeDetailViewModelTests: XCTestCase {

  private var repository: RecordingAnnotationRepository!
  private var viewModel: EpisodeDetailViewModel!
  private var episode: Episode!

  override func setUp() async throws {
    try await super.setUp()

    repository = RecordingAnnotationRepository()
    viewModel = EpisodeDetailViewModel(annotationRepository: repository)
    episode = Episode(
      id: "episode-1",
      title: "Episode Detail Testing",
      podcastID: "pod-1",
      podcastTitle: "Testing Podcast",
      pubDate: Date(timeIntervalSince1970: 0),
      duration: 1_200,
      description: "Episode used for testing annotations",
      audioURL: URL(string: "https://example.com/audio.mp3")
    )
  }

  override func tearDown() async throws {
    repository = nil
    viewModel = nil
    episode = nil
    try await super.tearDown()
  }

  func testCreateNotePersistsAndReloads() async throws {
    // Given: An episode with no existing notes
    await repository.setNotes([], for: episode.id)
    viewModel.loadEpisode(episode)

    // When: Creating a new note
    let timestamp: TimeInterval = 42.5
    try await viewModel.createNote(
      text: "Key takeaway",
      tags: ["swift", "concurrency"],
      timestamp: timestamp
    )

    // Then: Repository and view model should reflect the new note
    let storedNotes = await repository.notes(for: episode.id)
    XCTAssertEqual(storedNotes.count, 1)
    XCTAssertEqual(storedNotes.first?.text, "Key takeaway")
    XCTAssertEqual(storedNotes.first?.tags, ["swift", "concurrency"])
    let storedTimestamp = try XCTUnwrap(storedNotes.first?.timestamp)
    XCTAssertEqual(storedTimestamp, timestamp, accuracy: 0.001)
    XCTAssertEqual(viewModel.notes.count, 1)
    XCTAssertEqual(viewModel.notes.first?.text, "Key takeaway")
  }

  func testUpdateNoteSavesChanges() async throws {
    // Given: An existing note already persisted
    let existing = EpisodeNote(
      episodeId: episode.id,
      text: "Draft note",
      tags: ["draft"],
      timestamp: 12
    )
    await repository.setNotes([existing], for: episode.id)
    viewModel.loadEpisode(episode)

    // When: Updating note text and tags
    try await viewModel.updateNote(
      existing,
      newText: "Refined insight",
      newTags: ["insight", "published"]
    )

    // Then: Note should be updated in persistence and published state
    let storedNotes = await repository.notes(for: episode.id)
    XCTAssertEqual(storedNotes.first?.text, "Refined insight")
    XCTAssertEqual(storedNotes.first?.tags, ["insight", "published"])
    XCTAssertEqual(viewModel.notes.first?.text, "Refined insight")
    XCTAssertEqual(viewModel.notes.first?.tags, ["insight", "published"])
    XCTAssertNotNil(viewModel.notes.first?.modifiedAt)
  }

  func testUpdateTranscriptSearchPopulatesResults() async throws {
    // Given: Transcript data stored in the repository
    let transcript = EpisodeTranscript(
      episodeId: episode.id,
      segments: [
        TranscriptSegment(startTime: 0, text: "Swift concurrency essentials"),
        TranscriptSegment(startTime: 12, text: "Other unrelated topic")
      ]
    )
    await repository.setTranscript(transcript, for: episode.id)
    viewModel.loadEpisode(episode)

    try await waitForTranscriptLoad()
    // When: Searching for transcript matches
    viewModel.updateTranscriptSearch(query: "swift")

    // Then: Results should include the matching segment with highlighting metadata
    XCTAssertEqual(viewModel.transcriptSearchResults.count, 1)
    XCTAssertEqual(viewModel.transcriptSearchResults.first?.segment.text, "Swift concurrency essentials")
    XCTAssertEqual(viewModel.transcriptSearchQuery, "swift")
  }

  // MARK: - Helpers

  private func waitForTranscriptLoad() async throws {
    for _ in 0..<50 {
      if viewModel.transcript != nil {
        return
      }
      try await Task.sleep(for: .milliseconds(10))
      await Task.yield()
    }
    XCTFail("Timed out waiting for transcript to load")
  }
}

// MARK: - RecordingAnnotationRepository

actor RecordingAnnotationRepository: EpisodeAnnotationRepository {
  private var metadataByEpisode: [String: EpisodeMetadata] = [:]
  private var notesByEpisode: [String: [EpisodeNote]] = [:]
  private var bookmarksByEpisode: [String: [EpisodeBookmark]] = [:]
  private var transcriptByEpisode: [String: EpisodeTranscript] = [:]

  // MARK: - Helpers

  func setNotes(_ notes: [EpisodeNote], for episodeId: String) {
    notesByEpisode[episodeId] = notes
  }

  func notes(for episodeId: String) -> [EpisodeNote] {
    notesByEpisode[episodeId] ?? []
  }

  func setTranscript(_ transcript: EpisodeTranscript, for episodeId: String) {
    transcriptByEpisode[episodeId] = transcript
  }

  // MARK: - Metadata

  func saveMetadata(_ metadata: EpisodeMetadata) async throws {
    metadataByEpisode[metadata.episodeId] = metadata
  }

  func loadMetadata(for episodeId: String) async throws -> EpisodeMetadata? {
    metadataByEpisode[episodeId]
  }

  func deleteMetadata(for episodeId: String) async throws {
    metadataByEpisode.removeValue(forKey: episodeId)
  }

  // MARK: - Notes

  func saveNote(_ note: EpisodeNote) async throws {
    var notes = notesByEpisode[note.episodeId] ?? []
    if let index = notes.firstIndex(where: { $0.id == note.id }) {
      notes[index] = note
    } else {
      notes.append(note)
    }
    notesByEpisode[note.episodeId] = notes
  }

  func loadNotes(for episodeId: String) async throws -> [EpisodeNote] {
    notesByEpisode[episodeId] ?? []
  }

  func loadNote(id: String) async throws -> EpisodeNote? {
    notesByEpisode.values.flatMap { $0 }.first { $0.id == id }
  }

  func deleteNote(id: String) async throws {
    for (episodeId, notes) in notesByEpisode {
      if let index = notes.firstIndex(where: { $0.id == id }) {
        var updated = notes
        updated.remove(at: index)
        notesByEpisode[episodeId] = updated
        break
      }
    }
  }

  func deleteAllNotes(for episodeId: String) async throws {
    notesByEpisode.removeValue(forKey: episodeId)
  }

  // MARK: - Bookmarks

  func saveBookmark(_ bookmark: EpisodeBookmark) async throws {
    var bookmarks = bookmarksByEpisode[bookmark.episodeId] ?? []
    if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
      bookmarks[index] = bookmark
    } else {
      bookmarks.append(bookmark)
    }
    bookmarksByEpisode[bookmark.episodeId] = bookmarks
  }

  func loadBookmarks(for episodeId: String) async throws -> [EpisodeBookmark] {
    bookmarksByEpisode[episodeId] ?? []
  }

  func loadBookmark(id: String) async throws -> EpisodeBookmark? {
    bookmarksByEpisode.values.flatMap { $0 }.first { $0.id == id }
  }

  func deleteBookmark(id: String) async throws {
    for (episodeId, bookmarks) in bookmarksByEpisode {
      if let index = bookmarks.firstIndex(where: { $0.id == id }) {
        var updated = bookmarks
        updated.remove(at: index)
        bookmarksByEpisode[episodeId] = updated
        break
      }
    }
  }

  func deleteAllBookmarks(for episodeId: String) async throws {
    bookmarksByEpisode.removeValue(forKey: episodeId)
  }

  // MARK: - Transcript

  func saveTranscript(_ transcript: EpisodeTranscript) async throws {
    transcriptByEpisode[transcript.episodeId] = transcript
  }

  func loadTranscript(for episodeId: String) async throws -> EpisodeTranscript? {
    transcriptByEpisode[episodeId]
  }

  func deleteTranscript(for episodeId: String) async throws {
    transcriptByEpisode.removeValue(forKey: episodeId)
  }
}

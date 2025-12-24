@preconcurrency import CombineSupport
import Foundation
import CoreModels
import PlaybackEngine
import Persistence

/// ViewModel for Episode Detail view, coordinates with EpisodePlaybackService
@MainActor
public class EpisodeDetailViewModel: ObservableObject {
  @Published public var episode: Episode?
  @Published public var isPlaying = false
  @Published public var currentPosition: TimeInterval = 0
  @Published public var progressFraction: Double = 0
  @Published public var formattedCurrentTime = "0:00"
  @Published public var formattedDuration = "0:00"
  @Published public var playbackSpeed: Float = 1.0
  @Published public var chapters: [Chapter] = []
  @Published public var currentChapter: Chapter?
  
  // Annotation properties
  @Published public var metadata: EpisodeMetadata?
  @Published public var notes: [EpisodeNote] = []
  @Published public var bookmarks: [EpisodeBookmark] = []
  @Published public var transcript: EpisodeTranscript?
  @Published public var userRating: Int?
  @Published public var transcriptSearchQuery: String = ""
  @Published public var transcriptSearchResults: [TranscriptSearchResult] = []

  private let playbackService: EpisodePlaybackService
  private let sleepTimer: SleepTimer
  private let annotationRepository: EpisodeAnnotationRepository
  private var cancellables = Set<AnyCancellable>()
  private var currentState: EpisodePlaybackState?

  // Enhanced player reference for extended features
  private var enhancedPlayer: EnhancedEpisodePlayer? {
    return playbackService as? EnhancedEpisodePlayer
  }

  public init(
    playbackService: EpisodePlaybackService? = nil,
    sleepTimer: SleepTimer? = nil,
    annotationRepository: EpisodeAnnotationRepository? = nil
  ) {
    // Use provided service or create enhanced player (fallback to stub for compatibility)
    self.playbackService = playbackService ?? EnhancedEpisodePlayer()
    // Create SleepTimer on MainActor to avoid Swift 6 concurrency violation
    if let providedTimer = sleepTimer {
      self.sleepTimer = providedTimer
    } else {
      self.sleepTimer = SleepTimer()
    }
    // Use provided repository or create default
    self.annotationRepository = annotationRepository ?? UserDefaultsEpisodeAnnotationRepository()
    observePlaybackState()
  }

  public func loadEpisode(_ episode: Episode) {
    self.episode = episode
    self.userRating = episode.rating
    // Episode currently has no chapters property; set empty and await parsing support
    self.chapters = []
    updateCurrentChapter()
    updatePlaybackSpeed()
    // Reset UI state when loading a new episode
    updateUIFromCurrentState()
    // Load annotations
    Task {
      await loadAnnotations(for: episode.id)
    }
  }
  
  private func loadAnnotations(for episodeId: String) async {
    do {
      let loadedMetadata = try await annotationRepository.loadMetadata(for: episodeId)
      let loadedNotes = try await annotationRepository.loadNotes(for: episodeId)
      let loadedBookmarks = try await annotationRepository.loadBookmarks(for: episodeId)
      let loadedTranscript = try await annotationRepository.loadTranscript(for: episodeId)
      
      // Update UI on main actor
      self.metadata = loadedMetadata
      self.notes = loadedNotes
      self.bookmarks = loadedBookmarks
      self.transcript = loadedTranscript
      refreshTranscriptSearchResults()
    } catch {
      // Silent failure - annotations are optional enhancements
      // TODO: Replace with proper logging framework when available
      #if DEBUG
      print("Failed to load annotations: \(error)")
      #endif
    }
  }

  public func playPause() {
    guard let episode = episode else { return }

    if isPlaying {
      playbackService.pause()
    } else {
      // Use episode's duration or a default
      let duration = episode.duration ?? 300.0  // 5 minutes default
      playbackService.play(episode: episode, duration: duration)
    }
  }

  // MARK: - Enhanced Controls

  public func skipForward() {
    enhancedPlayer?.skipForward()
  }

  public func skipBackward() {
    enhancedPlayer?.skipBackward()
  }

  public func seek(to position: TimeInterval) {
    enhancedPlayer?.seek(to: position)
  }

  public func setPlaybackSpeed(_ speed: Float) {
    enhancedPlayer?.setPlaybackSpeed(speed)
    self.playbackSpeed = speed
  }

  public func jumpToChapter(_ chapter: Chapter) {
    enhancedPlayer?.jumpToChapter(chapter)
  }

  public func markAsPlayed(_ played: Bool) {
    enhancedPlayer?.markEpisodeAs(played: played)
  }

  // MARK: - Sleep Timer

  public func startSleepTimer(duration: TimeInterval) {
    sleepTimer.start(duration: duration)
  }

  public func stopSleepTimer() {
    sleepTimer.stop()
  }

  public func resetSleepTimer() {
    sleepTimer.reset()
  }

  public var sleepTimerActive: Bool {
    sleepTimer.isActive
  }

  public var sleepTimerRemainingTime: TimeInterval {
    sleepTimer.remainingTime
  }
  
  // MARK: - Annotation Management
  
  /// Add or update a note
  public func saveNote(_ note: EpisodeNote) {
    Task {
      do {
        try await annotationRepository.saveNote(note)
        await loadNotes()
      } catch {
        #if DEBUG
        print("Failed to save note: \(error)")
        #endif
      }
    }
  }

  /// Delete a note
  public func deleteNote(_ note: EpisodeNote) {
    Task {
      do {
        try await annotationRepository.deleteNote(id: note.id)
        // Reload notes to update UI
        await loadNotes()
      } catch {
        #if DEBUG
        print("Failed to delete note: \(error)")
        #endif
      }
    }
  }
  
  /// Add a bookmark at current position
  public func addBookmarkAtCurrentPosition(label: String = "") {
    guard let episodeId = episode?.id else { return }
    let bookmark = EpisodeBookmark(
      episodeId: episodeId,
      timestamp: currentPosition,
      label: label
    )
    saveBookmark(bookmark)
  }

  /// Create a bookmark at a specific timestamp
  public func createBookmark(at timestamp: TimeInterval, label: String) {
    guard let episodeId = episode?.id else { return }
    let bookmark = EpisodeBookmark(
      episodeId: episodeId,
      timestamp: timestamp,
      label: label
    )
    saveBookmark(bookmark)
  }

  /// Save a bookmark
  public func saveBookmark(_ bookmark: EpisodeBookmark) {
    Task {
      do {
        try await annotationRepository.saveBookmark(bookmark)
        // Reload bookmarks to update UI
        await loadBookmarks()
      } catch {
        #if DEBUG
        print("Failed to save bookmark: \(error)")
        #endif
      }
    }
  }
  
  /// Delete a bookmark
  public func deleteBookmark(_ bookmark: EpisodeBookmark) {
    Task {
      do {
        try await annotationRepository.deleteBookmark(id: bookmark.id)
        // Reload bookmarks to update UI
        await loadBookmarks()
      } catch {
        #if DEBUG
        print("Failed to delete bookmark: \(error)")
        #endif
      }
    }
  }
  
  /// Jump to a bookmark's position
  public func jumpToBookmark(_ bookmark: EpisodeBookmark) {
    seek(to: bookmark.timestamp)
  }
  
  /// Set episode rating
  public func setRating(_ rating: Int?) {
    guard let episode = episode else { return }
    self.userRating = rating
    
    // Update episode model (will persist when episode is saved by the app)
    // Note: Episode persistence happens at app level, not in this ViewModel
    let updatedEpisode = episode.withRating(rating)
    self.episode = updatedEpisode
  }
  
  /// Search transcript
  public func searchTranscript(_ query: String) -> [TranscriptSearchResult] {
    guard let transcript = transcript else { return [] }
    return transcript.searchWithRanges(query)
  }

  /// Jump to transcript segment
  public func jumpToTranscriptSegment(_ segment: TranscriptSegment) {
    seek(to: segment.startTime)
  }

  /// Create a new note for the current episode
  public func createNote(
    text: String,
    tags: [String],
    timestamp: TimeInterval?
  ) async throws {
    guard let episodeId = episode?.id else { return }
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else { return }

    let cleanedTags = tags
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    let note = EpisodeNote(
      episodeId: episodeId,
      text: trimmedText,
      tags: cleanedTags,
      timestamp: timestamp
    )

    try await annotationRepository.saveNote(note)
    await loadNotes()
  }

  /// Update an existing note with new text and tags
  public func updateNote(
    _ note: EpisodeNote,
    newText: String,
    newTags: [String]
  ) async throws {
    let trimmedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else { return }

    let cleanedTags = newTags
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    var updatedNote = note.withText(trimmedText)
    updatedNote = updatedNote.withTags(cleanedTags)

    try await annotationRepository.saveNote(updatedNote)
    await loadNotes()
  }

  /// Update the transcript search query and results
  public func updateTranscriptSearch(query: String) {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    transcriptSearchQuery = trimmedQuery

    guard !trimmedQuery.isEmpty, let transcript else {
      transcriptSearchResults = []
      return
    }

    transcriptSearchResults = transcript.searchWithRanges(trimmedQuery)
  }

  private func refreshTranscriptSearchResults() {
    guard !transcriptSearchQuery.isEmpty else {
      transcriptSearchResults = []
      return
    }

    transcriptSearchResults = transcript?.searchWithRanges(transcriptSearchQuery) ?? []
  }

  private func loadNotes() async {
    guard let episodeId = episode?.id else { return }
    do {
      let loadedNotes = try await annotationRepository.loadNotes(for: episodeId)
      self.notes = loadedNotes
    } catch {
      #if DEBUG
      print("Failed to reload notes: \(error)")
      #endif
    }
  }
  
  private func loadBookmarks() async {
    guard let episodeId = episode?.id else { return }
    do {
      let loadedBookmarks = try await annotationRepository.loadBookmarks(for: episodeId)
      self.bookmarks = loadedBookmarks
    } catch {
      #if DEBUG
      print("Failed to reload bookmarks: \(error)")
      #endif
    }
  }

  private func observePlaybackState() {
    playbackService.statePublisher
      .sink { [weak self] state in
        Task { @MainActor in
          self?.currentState = state
          self?.updateUI(for: state)
        }
      }
      .store(in: &cancellables)
  }

  private func updateUIFromCurrentState() {
    if let state = currentState {
      updateUI(for: state)
    }
  }

  private func updateUI(for state: EpisodePlaybackState) {
    switch state {
    case .idle(_):
      isPlaying = false
      currentPosition = 0
      progressFraction = 0
      formattedCurrentTime = "0:00"
      formattedDuration = "0:00"

    case .playing(_, let position, let duration):
      isPlaying = true
      currentPosition = position
      updateProgress(position: position, duration: duration)

    case .paused(_, let position, let duration):
      isPlaying = false
      currentPosition = position
      updateProgress(position: position, duration: duration)

    case .finished(_, let duration):
      isPlaying = false
      currentPosition = duration
      updateProgress(position: duration, duration: duration)
    case .failed(_, let position, let duration, _):
      isPlaying = false
      currentPosition = position
      updateProgress(position: position, duration: duration)
    }

    updateCurrentChapter()
  }

  private func updateProgress(position: TimeInterval, duration: TimeInterval) {
    progressFraction = duration > 0 ? min(max(position / duration, 0), 1) : 0
    formattedCurrentTime = formatTime(position)
    formattedDuration = formatTime(duration)
  }

  private func updateCurrentChapter() {
    guard !chapters.isEmpty else {
      currentChapter = nil
      return
    }

    // Find the current chapter based on position
    currentChapter = chapters.last { chapter in
      chapter.startTime <= currentPosition
    }
  }

  private func updatePlaybackSpeed() {
    if let player = enhancedPlayer {
      playbackSpeed = player.getCurrentPlaybackSpeed()
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    let remainingSeconds = Int(seconds) % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
  }
}

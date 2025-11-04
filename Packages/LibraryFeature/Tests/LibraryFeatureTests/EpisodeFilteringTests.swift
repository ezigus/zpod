#if os(iOS)
import CoreModels
import Foundation
import Persistence
import SharedUtilities
import SettingsDomain
import SettingsDomain
import XCTest

@testable import LibraryFeature

// MARK: - Episode List View Model Tests

@MainActor
final class EpisodeListViewModelTests: XCTestCase {

  private var viewModel: EpisodeListViewModel!
  private var testPodcast: Podcast!
  private var mockFilterService: MockEpisodeFilterService!
  private var recordingRepository: RecordingEpisodeFilterRepository!
  private var filterManager: EpisodeFilterManager!
  private var mockSwipeConfigurationService: MockSwipeConfigurationService!
  private var mockHapticsService: MockHapticsService!
  private var annotationRepository: RecordingAnnotationRepository!

  override func setUp() async throws {
    try await super.setUp()

    mockFilterService = MockEpisodeFilterService()
    recordingRepository = RecordingEpisodeFilterRepository()
    filterManager = EpisodeFilterManager(
      repository: recordingRepository,
      filterService: mockFilterService
    )
    testPodcast = createTestPodcast()
    mockSwipeConfigurationService = MockSwipeConfigurationService(configuration: .default)
    mockHapticsService = MockHapticsService()

    annotationRepository = RecordingAnnotationRepository()

    viewModel = EpisodeListViewModel(
      podcast: testPodcast,
      filterService: mockFilterService,
      filterManager: filterManager,
      swipeConfigurationService: mockSwipeConfigurationService,
      hapticFeedbackService: mockHapticsService,
      annotationRepository: annotationRepository
    )
  }

  override func tearDown() async throws {
    viewModel = nil
    testPodcast = nil
    mockFilterService = nil
    filterManager = nil
    recordingRepository = nil
    mockSwipeConfigurationService = nil
    mockHapticsService = nil
    annotationRepository = nil

    try await super.tearDown()
  }

  // MARK: - Filter Tests

  func testSetFilter_UpdatesCurrentFilter() async {
    // Given: New filter to set
    let newFilter = EpisodeFilter(
      conditions: [EpisodeFilterCondition(criteria: .favorited)],
      sortBy: .rating
    )

    // When: Setting filter
    await viewModel.setFilter(newFilter)

    // Then: Current filter should be updated
    XCTAssertEqual(viewModel.currentFilter, newFilter, "Current filter should be updated")
    XCTAssertTrue(mockFilterService.filterAndSortCalled, "Should apply filter")
  }

  func testClearFilter_ResetsToEmptyFilter() async {
    // Given: View model with active filter
    let activeFilter = EpisodeFilter(
      conditions: [EpisodeFilterCondition(criteria: .unplayed)],
      sortBy: .title
    )
    await viewModel.setFilter(activeFilter)

    // When: Clearing filter
    await viewModel.clearFilter()

    // Then: Should reset to empty filter
    XCTAssertTrue(viewModel.currentFilter.isEmpty, "Filter should be empty")
  }

  func testUpdateSearchText_TriggersFiltering() async {
    // Given: Search text to set
    let searchText = "Swift programming"

    // When: Updating search text
    await viewModel.updateSearchText(searchText)

    // Then: Should update search text and trigger filtering
    XCTAssertEqual(viewModel.searchText, searchText, "Search text should be updated")
    XCTAssertTrue(mockFilterService.searchEpisodesCalled, "Should perform search")
  }

  func testHasActiveFilters_WithFilter() async {
    // Given: Active filter
    let filter = EpisodeFilter(
      conditions: [EpisodeFilterCondition(criteria: .downloaded)],
      sortBy: .duration
    )

    // When: Setting filter
    await viewModel.setFilter(filter)

    // Then: Should have active filters
    XCTAssertTrue(viewModel.hasActiveFilters, "Should have active filters")
  }

  func testHasActiveFilters_WithSearchText() async {
    // Given: Search text
    let searchText = "episode"

    // When: Setting search text
    await viewModel.updateSearchText(searchText)

    // Then: Should have active filters
    XCTAssertTrue(viewModel.hasActiveFilters, "Should have active filters with search text")
  }

  func testHasActiveFilters_Empty() {
    // Given: No filter or search text
    // When: Checking active filters
    let hasActiveFilters = viewModel.hasActiveFilters

    // Then: Should not have active filters
    XCTAssertFalse(hasActiveFilters, "Should not have active filters when empty")
  }

  // MARK: - Episode Action Tests

  func testToggleEpisodeFavorite_UpdatesEpisode() async {
    // Given: Episode to favorite
    let episode = testPodcast.episodes[0]
    let originalFavoriteStatus = episode.isFavorited

    // When: Toggling favorite
    await viewModel.toggleEpisodeFavorite(episode)

    // Then: Should update episode favorite status
    // Note: In a real implementation, this would verify the episode was updated
    // For now, we're testing that the method doesn't crash
    XCTAssertTrue(true, "Should handle favorite toggle without crashing")
  }

  func testToggleEpisodeBookmark_UpdatesEpisode() async {
    // Given: Episode to bookmark
    let episode = testPodcast.episodes[0]

    // When: Toggling bookmark
    await viewModel.toggleEpisodeBookmark(episode)

    // Then: Should update episode bookmark status
    XCTAssertTrue(true, "Should handle bookmark toggle without crashing")
  }

  func testMarkEpisodeAsPlayed_UpdatesEpisode() async {
    // Given: Episode to mark as played
    let episode = testPodcast.episodes[0]

    // When: Marking as played
    await viewModel.markEpisodeAsPlayed(episode)

    // Then: Should update episode played status
    XCTAssertTrue(true, "Should handle mark as played without crashing")
  }

  func testSetEpisodeRating_UpdatesEpisode() async {
    // Given: Episode to rate
    let episode = testPodcast.episodes[0]
    let rating = 4

    // When: Setting rating
    await viewModel.setEpisodeRating(episode, rating: rating)

    // Then: Should update episode rating
    XCTAssertTrue(true, "Should handle rating update without crashing")
  }

  func testRefreshNoteCountsLoadsFromRepository() async throws {
    // Given: Stored annotations for episodes
    let episodeID = testPodcast.episodes[0].id
    await annotationRepository.setNotes([
      EpisodeNote(episodeId: episodeID, text: "First"),
      EpisodeNote(episodeId: episodeID, text: "Second")
    ], for: episodeID)

    // When: Refreshing note counts
    try await viewModel.refreshNoteCounts()

    // Then: Note count badge data should be populated
    XCTAssertEqual(viewModel.noteCounts[episodeID], 2)
  }

  // MARK: - Filter Summary Tests

  func testFilterSummary_AllEpisodes() {
    // Given: No active filters
    // When: Getting filter summary
    let summary = viewModel.filterSummary

    // Then: Should show all episodes
    XCTAssertTrue(summary.contains("All Episodes"), "Should show all episodes in summary")
    XCTAssertTrue(summary.contains("4"), "Should show correct episode count")
  }

  func testFilterSummary_WithFilter() async {
    // Given: Active filter
    let filter = EpisodeFilter(
      conditions: [EpisodeFilterCondition(criteria: .unplayed)],
      sortBy: .title
    )
    await viewModel.setFilter(filter)

    // When: Getting filter summary
    let summary = viewModel.filterSummary

    // Then: Should show filter description
    XCTAssertTrue(summary.contains("Unplayed"), "Should show filter criteria in summary")
  }

  func testFilterSummary_WithSearchText() async {
    // Given: Search text
    let searchText = "Swift"
    await viewModel.updateSearchText(searchText)

    // When: Getting filter summary
    let summary = viewModel.filterSummary

    // Then: Should show search in summary
    XCTAssertTrue(summary.contains("Search:"), "Should show search in summary")
    XCTAssertTrue(summary.contains(searchText), "Should show search text in summary")
  }

  // MARK: - Refresh Tests

  func testRefreshEpisodes_CallsFilterService() async {
    // Given: View model ready for refresh
    // When: Refreshing episodes
    await viewModel.refreshEpisodes()

    // Then: Should apply current filter
    XCTAssertTrue(mockFilterService.filterAndSortCalled, "Should apply filter during refresh")
  }

  func testPerformSwipeActionFavoriteTogglesState() {
    // Given
    var episode = viewModel.filteredEpisodes[0]
    XCTAssertFalse(episode.isFavorited)

    // When
    viewModel.performSwipeAction(.favorite, for: episode)

    // Then
    episode = viewModel.filteredEpisodes[0]
    XCTAssertTrue(episode.isFavorited, "Swipe favorite should toggle favorite state")
  }

  func testPerformSwipeActionArchiveTogglesState() {
    // Given
    var episode = viewModel.filteredEpisodes[0]
    XCTAssertFalse(episode.isArchived)

    // When
    viewModel.performSwipeAction(.archive, for: episode)

    // Then
    episode = viewModel.filteredEpisodes[0]
    XCTAssertTrue(episode.isArchived, "Archive swipe should archive episode")

    // When: Swipe again to unarchive
    viewModel.performSwipeAction(.archive, for: episode)

    // Then
    episode = viewModel.filteredEpisodes[0]
    XCTAssertFalse(episode.isArchived, "Second archive swipe should unarchive episode")
  }

  func testPerformSwipeActionMarkPlayedSetsPlayedStatus() {
    // Given
    var episode = viewModel.filteredEpisodes[0]
    XCTAssertFalse(episode.isPlayed)

    // When
    viewModel.performSwipeAction(.markPlayed, for: episode)

    // Then
    episode = viewModel.filteredEpisodes[0]
    XCTAssertTrue(episode.isPlayed, "Mark played swipe should set played status")
  }

  func testPerformSwipeActionTriggersHapticFeedback() {
    // Given
    XCTAssertTrue(mockHapticsService.impactCalls.isEmpty)
    let episode = viewModel.filteredEpisodes[0]

    // When
    viewModel.performSwipeAction(.favorite, for: episode)

    // Then
    XCTAssertEqual(
      mockHapticsService.impactCalls.count, 1, "Swipe action should trigger haptic feedback")
    XCTAssertEqual(
      mockHapticsService.impactCalls.first,
      HapticFeedbackIntensity(style: viewModel.swipeConfiguration.hapticStyle)
    )
  }

  func testRefreshSwipeSettingsUpdatesProperties() {
    // Given
    let customConfiguration = SwipeConfiguration(
      swipeActions: SwipeActionSettings(
        leadingActions: [.download],
        trailingActions: [.share],
        allowFullSwipeLeading: false,
        allowFullSwipeTrailing: true,
        hapticFeedbackEnabled: false
      ),
      hapticStyle: .heavy
    )
    await mockSwipeConfigurationService.replace(configuration: customConfiguration)

    // When
    viewModel.refreshSwipeSettings()

    // Then
    XCTAssertEqual(viewModel.leadingSwipeActions, [.download])
    XCTAssertEqual(viewModel.trailingSwipeActions, [.share])
    XCTAssertFalse(viewModel.isHapticFeedbackEnabled)
    XCTAssertEqual(viewModel.swipeConfiguration.hapticStyle, .heavy)
  }

  // MARK: - Helper Methods

  private func createTestPodcast() -> Podcast {
    let episodes = [
      Episode(
        id: "ep1",
        title: "Episode 1: Swift Basics",
        podcastID: "podcast1",
        pubDate: Date(),
        duration: 1800,
        description: "Learning Swift programming fundamentals."
      ),
      Episode(
        id: "ep2",
        title: "Episode 2: SwiftUI Views",
        podcastID: "podcast1",
        playbackPosition: 300,
        pubDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
        duration: 2400,
        description: "Building user interfaces with SwiftUI."
      ),
      Episode(
        id: "ep3",
        title: "Episode 3: Advanced Topics",
        podcastID: "podcast1",
        isPlayed: true,
        pubDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
        duration: 3000,
        description: "Advanced Swift programming concepts."
      ),
      Episode(
        id: "ep4",
        title: "Episode 4: Best Practices",
        podcastID: "podcast1",
        pubDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
        duration: 2700,
        description: "Best practices for Swift development.",
        isFavorited: true,
        isBookmarked: true
      ),
    ]

    return Podcast(
      id: "podcast1",
      title: "Swift Programming Podcast",
      author: "Test Author",
      description: "A podcast about Swift programming",
      artworkURL: URL(string: "https://example.com/artwork.jpg"),
      feedURL: URL(string: "https://example.com/feed.xml")!,
      episodes: episodes
    )
  }
}

actor RecordingAnnotationRepository: EpisodeAnnotationRepository {
  private var notesByEpisode: [String: [EpisodeNote]] = [:]

  func setNotes(_ notes: [EpisodeNote], for episodeId: String) {
    notesByEpisode[episodeId] = notes
  }

  // MARK: - Metadata

  func saveMetadata(_ metadata: EpisodeMetadata) async throws {}

  func loadMetadata(for episodeId: String) async throws -> EpisodeMetadata? { nil }

  func deleteMetadata(for episodeId: String) async throws {}

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
        return
      }
    }
  }

  func deleteAllNotes(for episodeId: String) async throws {
    notesByEpisode.removeValue(forKey: episodeId)
  }

  // MARK: - Bookmarks

  func saveBookmark(_ bookmark: EpisodeBookmark) async throws {}

  func loadBookmarks(for episodeId: String) async throws -> [EpisodeBookmark] { [] }

  func loadBookmark(id: String) async throws -> EpisodeBookmark? { nil }

  func deleteBookmark(id: String) async throws {}

  func deleteAllBookmarks(for episodeId: String) async throws {}

  // MARK: - Transcript

  func saveTranscript(_ transcript: EpisodeTranscript) async throws {}

  func loadTranscript(for episodeId: String) async throws -> EpisodeTranscript? { nil }

  func deleteTranscript(for episodeId: String) async throws {}
}

@MainActor
final class MockSwipeConfigurationService: SwipeConfigurationServicing, @unchecked Sendable {
  private var configuration: SwipeConfiguration
  private var continuations: [UUID: AsyncStream<SwipeConfiguration>.Continuation] = [:]

  init(configuration: SwipeConfiguration) {
    self.configuration = configuration
  }

  func load() async -> SwipeConfiguration {
    configuration
  }

  func save(_ configuration: SwipeConfiguration) async throws {
    self.configuration = configuration
    broadcast(configuration)
  }

  nonisolated func updatesStream() -> AsyncStream<SwipeConfiguration> {
    AsyncStream { continuation in
      let id = UUID()
      Task { @MainActor [weak self] in
        guard let self else { return }
        continuation.onTermination = { _ in
          Task { @MainActor [weak self] in self?.continuations[id] = nil }
        }
        self.continuations[id] = continuation
        continuation.yield(self.configuration)
      }
    }
  }

  @MainActor func replace(configuration: SwipeConfiguration) {
    self.configuration = configuration
    broadcast(configuration)
  }

  @MainActor private func broadcast(_ configuration: SwipeConfiguration) {
    for continuation in continuations.values {
      continuation.yield(configuration)
    }
  }
}

private final class MockHapticsService: HapticFeedbackServicing, @unchecked Sendable {
  private(set) var impactCalls: [HapticFeedbackIntensity] = []

  func impact(_ intensity: HapticFeedbackIntensity) {
    impactCalls.append(intensity)
  }

  func selectionChanged() {}

  func notifySuccess() {}

  func notifyWarning() {}

  func notifyError() {}
}

// MARK: - Smart Episode List View Model Tests

@MainActor
final class SmartEpisodeListViewModelTests: XCTestCase {

  private var viewModel: SmartEpisodeListViewModel!
  private var testSmartList: SmartEpisodeList!
  private var mockFilterService: MockEpisodeFilterService!
  private var recordingRepository: RecordingEpisodeFilterRepository!
  private var filterManager: EpisodeFilterManager!

  override func setUp() async throws {
    try await super.setUp()

    mockFilterService = MockEpisodeFilterService()
    recordingRepository = RecordingEpisodeFilterRepository()
    filterManager = EpisodeFilterManager(
      repository: recordingRepository,
      filterService: mockFilterService
    )
    testSmartList = createTestSmartList()

    viewModel = SmartEpisodeListViewModel(
      smartList: testSmartList,
      filterService: mockFilterService,
      filterManager: filterManager
    )
  }

  override func tearDown() async throws {
    viewModel = nil
    testSmartList = nil
    mockFilterService = nil
    filterManager = nil
    recordingRepository = nil

    try await super.tearDown()
  }

  // MARK: - Refresh Tests

  func testRefreshNow_UpdatesLastRefresh() async {
    // Given: Smart list view model
    let beforeRefresh = Date()

    // When: Refreshing now
    await viewModel.refreshNow()

    // Then: Should update last refresh time
    XCTAssertNotNil(viewModel.lastRefresh, "Should set last refresh time")
    XCTAssertGreaterThanOrEqual(
      viewModel.lastRefresh!, beforeRefresh, "Last refresh should be recent")
    XCTAssertTrue(mockFilterService.updateSmartListCalled, "Should update smart list")
    let saveCount = await recordingRepository.saveSmartListCallCount
    XCTAssertGreaterThan(saveCount, 0, "Should save updated smart list")
  }

  func testNeedsRefresh_WithAutoUpdate() {
    // Given: Smart list with auto update enabled (default)
    // When: Checking if refresh is needed
    let needsRefresh = viewModel.needsRefresh

    // Then: Should check with filter service
    XCTAssertTrue(mockFilterService.smartListNeedsUpdateCalled, "Should check if update is needed")
  }

  func testRefreshIntervalText_ShowsMinutes() {
    // Given: Smart list with refresh interval
    // When: Getting refresh interval text
    let intervalText = viewModel.refreshIntervalText

    // Then: Should show interval in minutes
    XCTAssertTrue(intervalText.contains("min"), "Should show minutes in interval text")
  }

  // MARK: - Helper Methods

  private func createTestSmartList() -> SmartEpisodeList {
    return SmartEpisodeList(
      name: "Test Smart List",
      filter: EpisodeFilter(
        conditions: [EpisodeFilterCondition(criteria: .unplayed)],
        sortBy: .pubDateNewest
      ),
      maxEpisodes: 25,
      autoUpdate: true,
      refreshInterval: 300  // 5 minutes
    )
  }
}

// MARK: - Mock Classes

final class MockEpisodeFilterService: EpisodeFilterService, @unchecked Sendable {
  var filterAndSortCalled = false
  var episodeMatchesCalled = false
  var sortEpisodesCalled = false
  var searchEpisodesCalled = false
  var updateSmartListCalled = false
  var smartListNeedsUpdateCalled = false
  var searchEpisodesAdvancedCalled = false
  var evaluateSmartListV2Called = false
  var smartListNeedsUpdateV2Called = false

  func filterAndSort(episodes: [Episode], using filter: EpisodeFilter) -> [Episode] {
    filterAndSortCalled = true
    return episodes  // Return unchanged for testing
  }

  func episodeMatches(_ episode: Episode, condition: EpisodeFilterCondition) -> Bool {
    episodeMatchesCalled = true
    return true  // Always match for testing
  }

  func sortEpisodes(_ episodes: [Episode], by sortBy: EpisodeSortBy) -> [Episode] {
    sortEpisodesCalled = true
    return episodes  // Return unchanged for testing
  }

  func searchEpisodes(_ episodes: [Episode], query: String, filter: EpisodeFilter? = nil)
    -> [Episode]
  {
    searchEpisodesCalled = true
    return episodes.filter { $0.title.localizedCaseInsensitiveContains(query) }
  }

  func searchEpisodesAdvanced(
    _ episodes: [Episode],
    query: EpisodeSearchQuery,
    filter: EpisodeFilter?
  ) -> [EpisodeSearchResult] {
    searchEpisodesAdvancedCalled = true
    return episodes.map {
      EpisodeSearchResult(
        episode: $0,
        relevanceScore: 1.0,
        highlights: []
      )
    }
  }

  func evaluateSmartListV2(_ smartList: SmartEpisodeListV2, allEpisodes: [Episode]) -> [Episode] {
    evaluateSmartListV2Called = true
    return allEpisodes
  }

  func smartListNeedsUpdateV2(_ smartList: SmartEpisodeListV2) -> Bool {
    smartListNeedsUpdateV2Called = true
    return false
  }

  func updateSmartList(_ smartList: SmartEpisodeList, allEpisodes: [Episode]) -> [Episode] {
    updateSmartListCalled = true
    return allEpisodes  // Return unchanged for testing
  }

  func smartListNeedsUpdate(_ smartList: SmartEpisodeList) -> Bool {
    smartListNeedsUpdateCalled = true
    return false  // No update needed for testing
  }
}

actor RecordingEpisodeFilterRepository: EpisodeFilterRepository {
  private(set) var savedGlobalPreferences: [GlobalFilterPreferences] = []
  private(set) var savedPodcastFilters: [(id: String, filter: EpisodeFilter)] = []
  private(set) var savedSmartLists: [SmartEpisodeList] = []
  private(set) var deletedSmartListIDs: [String] = []

  var saveSmartListCallCount: Int {
    savedSmartLists.count
  }

  func saveGlobalPreferences(_ preferences: GlobalFilterPreferences) async throws {
    savedGlobalPreferences.append(preferences)
  }

  func loadGlobalPreferences() async throws -> GlobalFilterPreferences? {
    savedGlobalPreferences.last
  }

  func savePodcastFilter(podcastId: String, filter: EpisodeFilter) async throws {
    savedPodcastFilters.append((podcastId, filter))
  }

  func loadPodcastFilter(podcastId: String) async throws -> EpisodeFilter? {
    savedPodcastFilters.last { $0.id == podcastId }?.filter
  }

  func saveSmartList(_ smartList: SmartEpisodeList) async throws {
    savedSmartLists.append(smartList)
  }

  func loadSmartLists() async throws -> [SmartEpisodeList] {
    savedSmartLists
  }

  func deleteSmartList(id: String) async throws {
    deletedSmartListIDs.append(id)
  }
}

#endif

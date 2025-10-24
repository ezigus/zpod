import XCTest
import Foundation
@testable import Persistence
import CoreModels

// MARK: - Episode Filter Repository Tests

final class EpisodeFilterRepositoryTests: XCTestCase {
    
    private var repository: UserDefaultsEpisodeFilterRepository!
    private var userDefaults: UserDefaults!
    private var suiteName: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create isolated UserDefaults for testing
        suiteName = "test-episode-filter-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        
        repository = UserDefaultsEpisodeFilterRepository(userDefaults: userDefaults)
    }
    
    override func tearDown() async throws {
        userDefaults?.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        repository = nil
        suiteName = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Global Preferences Tests
    
    func testSaveAndLoadGlobalPreferences_Success() async throws {
        // Given: Global filter preferences to save
        let preferences = createTestGlobalPreferences()
        
        // When: Saving and loading preferences
        try await repository.saveGlobalPreferences(preferences)
        let loadedPreferences = try await repository.loadGlobalPreferences()
        
        // Then: Should load the same preferences
        XCTAssertNotNil(loadedPreferences, "Should load saved preferences")
        XCTAssertEqual(loadedPreferences, preferences, "Loaded preferences should match saved preferences")
    }
    
    func testLoadGlobalPreferences_NoData() async throws {
        // Given: No saved preferences
        // When: Loading preferences
        let loadedPreferences = try await repository.loadGlobalPreferences()
        
        // Then: Should return nil
        XCTAssertNil(loadedPreferences, "Should return nil when no preferences are saved")
    }
    
    // MARK: - Podcast Filter Tests
    
    func testSaveAndLoadPodcastFilter_Success() async throws {
        // Given: Podcast filter to save
        let podcastId = "test-podcast-123"
        let filter = createTestEpisodeFilter()
        
        // When: Saving and loading podcast filter
        try await repository.savePodcastFilter(podcastId: podcastId, filter: filter)
        let loadedFilter = try await repository.loadPodcastFilter(podcastId: podcastId)
        
        // Then: Should load the same filter
        XCTAssertNotNil(loadedFilter, "Should load saved podcast filter")
        XCTAssertEqual(loadedFilter, filter, "Loaded filter should match saved filter")
    }
    
    func testLoadPodcastFilter_NoData() async throws {
        // Given: No saved podcast filter
        let podcastId = "nonexistent-podcast"
        
        // When: Loading podcast filter
        let loadedFilter = try await repository.loadPodcastFilter(podcastId: podcastId)
        
        // Then: Should return nil
        XCTAssertNil(loadedFilter, "Should return nil when no podcast filter is saved")
    }
    
    func testSaveMultiplePodcastFilters() async throws {
        // Given: Multiple podcast filters
        let podcast1Id = "podcast-1"
        let podcast2Id = "podcast-2"
        let filter1 = createTestEpisodeFilter()
        let filter2 = EpisodeFilter(
            conditions: [EpisodeFilterCondition(criteria: .favorited)],
            logic: .and,
            sortBy: .rating
        )
        
        // When: Saving multiple filters
        try await repository.savePodcastFilter(podcastId: podcast1Id, filter: filter1)
        try await repository.savePodcastFilter(podcastId: podcast2Id, filter: filter2)
        
        // Then: Should load correct filters for each podcast
        let loadedFilter1 = try await repository.loadPodcastFilter(podcastId: podcast1Id)
        let loadedFilter2 = try await repository.loadPodcastFilter(podcastId: podcast2Id)
        
        XCTAssertEqual(loadedFilter1, filter1, "First podcast filter should be correct")
        XCTAssertEqual(loadedFilter2, filter2, "Second podcast filter should be correct")
    }
    
    // MARK: - Smart List Tests
    
    func testSaveAndLoadSmartLists_Success() async throws {
        // Given: Smart episode lists to save
        let smartList1 = createTestSmartList(name: "Unplayed Episodes")
        let smartList2 = createTestSmartList(name: "Favorite Episodes")
        
        // When: Saving smart lists
        try await repository.saveSmartList(smartList1)
        try await repository.saveSmartList(smartList2)
        
        // Then: Should load all smart lists
        let loadedSmartLists = try await repository.loadSmartLists()
        
        XCTAssertEqual(loadedSmartLists.count, 2, "Should load all saved smart lists")
        
        let loadedIds = Set(loadedSmartLists.map { $0.id })
        XCTAssertTrue(loadedIds.contains(smartList1.id), "Should contain first smart list")
        XCTAssertTrue(loadedIds.contains(smartList2.id), "Should contain second smart list")
    }
    
    func testLoadSmartLists_NoData() async throws {
        // Given: No saved smart lists
        // When: Loading smart lists
        let loadedSmartLists = try await repository.loadSmartLists()
        
        // Then: Should return empty array
        XCTAssertTrue(loadedSmartLists.isEmpty, "Should return empty array when no smart lists are saved")
    }
    
    func testDeleteSmartList_Success() async throws {
        // Given: Saved smart lists
        let smartList1 = createTestSmartList(name: "List 1")
        let smartList2 = createTestSmartList(name: "List 2")
        
        try await repository.saveSmartList(smartList1)
        try await repository.saveSmartList(smartList2)
        
        // When: Deleting one smart list
        try await repository.deleteSmartList(id: smartList1.id)
        
        // Then: Should only have remaining smart list
        let loadedSmartLists = try await repository.loadSmartLists()
        
        XCTAssertEqual(loadedSmartLists.count, 1, "Should have one remaining smart list")
        XCTAssertEqual(loadedSmartLists.first?.id, smartList2.id, "Remaining list should be the correct one")
    }
    
    func testUpdateSmartList_Success() async throws {
        // Given: Saved smart list
        let originalSmartList = createTestSmartList(name: "Original")
        try await repository.saveSmartList(originalSmartList)
        
        // When: Updating smart list
        let updatedSmartList = SmartEpisodeList(
            id: originalSmartList.id, // Same ID
            name: "Updated Name",
            filter: originalSmartList.filter,
            maxEpisodes: 50, // Changed
            autoUpdate: false, // Changed
            refreshInterval: 600, // Changed
            createdAt: originalSmartList.createdAt,
            lastUpdated: Date()
        )
        try await repository.saveSmartList(updatedSmartList)
        
        // Then: Should have updated smart list
        let loadedSmartLists = try await repository.loadSmartLists()
        
        XCTAssertEqual(loadedSmartLists.count, 1, "Should still have one smart list")
        
        let loadedList = loadedSmartLists.first!
        XCTAssertEqual(loadedList.id, originalSmartList.id, "Should have same ID")
        XCTAssertEqual(loadedList.name, "Updated Name", "Should have updated name")
        XCTAssertEqual(loadedList.maxEpisodes, 50, "Should have updated max episodes")
        XCTAssertFalse(loadedList.autoUpdate, "Should have updated auto update setting")
    }
    
    // MARK: - Performance Tests
    
    func testSaveMultipleSmartLists_Performance() async throws {
        // Given: Large number of smart lists
        let smartLists = (1...100).map { index in
            createTestSmartList(name: "Smart List \(index)")
        }
        
        // When: Saving all smart lists
        let startTime = Date()
        
        for smartList in smartLists {
            try await repository.saveSmartList(smartList)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then: Should complete within reasonable time
        XCTAssertLessThan(duration, 5.0, "Should save 100 smart lists within 5 seconds")
        
        // Verify all were saved
        let loadedSmartLists = try await repository.loadSmartLists()
        XCTAssertEqual(loadedSmartLists.count, 100, "Should save all smart lists")
    }
    
    // MARK: - Helper Methods
    
    private func createTestGlobalPreferences() -> GlobalFilterPreferences {
        let defaultFilter = createTestEpisodeFilter()
        let smartList = createTestSmartList()
        
        return GlobalFilterPreferences(
            defaultFilter: defaultFilter,
            defaultSortBy: .pubDateNewest,
            savedPresets: EpisodeFilterPreset.builtInPresets,
            smartLists: [smartList],
            perPodcastPreferences: ["test-podcast": defaultFilter]
        )
    }
    
    private func createTestEpisodeFilter() -> EpisodeFilter {
        return EpisodeFilter(
            conditions: [
                EpisodeFilterCondition(criteria: .unplayed),
                EpisodeFilterCondition(criteria: .downloaded)
            ],
            logic: .and,
            sortBy: .pubDateNewest
        )
    }
    
    private func createTestSmartList(name: String = "Test Smart List") -> SmartEpisodeList {
        return SmartEpisodeList(
            name: name,
            filter: createTestEpisodeFilter(),
            maxEpisodes: 25,
            autoUpdate: true,
            refreshInterval: 300
        )
    }
}

// MARK: - Episode Filter Manager Tests

@MainActor
final class EpisodeFilterManagerTests: XCTestCase {
    
    private var filterManager: EpisodeFilterManager!
    private var mockRepository: MockEpisodeFilterRepository!
    private var filterService: DefaultEpisodeFilterService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()

        mockRepository = MockEpisodeFilterRepository()
        filterService = DefaultEpisodeFilterService()
        filterManager = EpisodeFilterManager(repository: mockRepository, filterService: filterService)
    }

    override func tearDownWithError() throws {
        filterManager = nil
        mockRepository = nil
        filterService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Filter Management Tests
    
    @MainActor
    func testSetCurrentFilter_UpdatesCurrentFilter() async {
        // Given: New filter to set
        let newFilter = EpisodeFilter(
            conditions: [EpisodeFilterCondition(criteria: .favorited)],
            sortBy: .rating
        )
        
        // When: Setting current filter
        await filterManager.setCurrentFilter(newFilter)
        
        // Then: Current filter should be updated
        XCTAssertEqual(filterManager.currentFilter, newFilter, "Current filter should be updated")
    }
    
    @MainActor
    func testSetCurrentFilter_ForPodcast_SavesPreference() async {
        // Given: Filter for specific podcast
        let podcastId = "test-podcast"
        let filter = EpisodeFilter(
            conditions: [EpisodeFilterCondition(criteria: .downloaded)],
            sortBy: .title
        )
        
        // When: Setting filter for podcast
        await filterManager.setCurrentFilter(filter, forPodcast: podcastId)
        
        // Then: Should save podcast preference
        XCTAssertTrue(mockRepository.savePodcastFilterCalled, "Should save podcast filter")
        XCTAssertEqual(mockRepository.lastSavedPodcastId, podcastId, "Should save for correct podcast")
        XCTAssertEqual(mockRepository.lastSavedPodcastFilter, filter, "Should save correct filter")
    }
    
    @MainActor
    func testFilterForPodcast_ReturnsCorrectFilter() {
        // Given: Podcast with saved filter preference
        let podcastId = "test-podcast"
        let savedFilter = EpisodeFilter(
            conditions: [EpisodeFilterCondition(criteria: .bookmarked)],
            sortBy: .dateAdded
        )
        
        // Setup global preferences with podcast preference
        await filterManager.setCurrentFilter(savedFilter, forPodcast: podcastId)

        // When: Getting filter for podcast
        let retrievedFilter = filterManager.filterForPodcast(podcastId)
        
        // Then: Should return saved filter
        XCTAssertEqual(retrievedFilter, savedFilter, "Should return saved podcast filter")
    }
    
    @MainActor
    func testFilterForPodcast_ReturnsDefaultFilter() {
        // Given: Podcast without saved filter preference
        let podcastId = "unknown-podcast"
        
        // When: Getting filter for podcast
        let retrievedFilter = filterManager.filterForPodcast(podcastId)
        
        // Then: Should return default filter
        XCTAssertEqual(retrievedFilter, filterManager.globalPreferences.defaultFilter, 
                      "Should return default filter for unknown podcast")
    }
    
    @MainActor
    func testCreateSmartList_AddsToSmartLists() async {
        // Given: Smart list to create
        let smartList = SmartEpisodeList(
            name: "Test Smart List",
            filter: EpisodeFilter(conditions: [EpisodeFilterCondition(criteria: .unplayed)])
        )
        
        // When: Creating smart list
        await filterManager.createSmartList(smartList)
        
        // Then: Should add to smart lists
        XCTAssertTrue(filterManager.smartLists.contains { $0.id == smartList.id }, 
                     "Should add smart list to collection")
        XCTAssertTrue(mockRepository.saveSmartListCalled, "Should save smart list to repository")
    }
    
    @MainActor
    func testDeleteSmartList_RemovesFromSmartLists() async {
        // Given: Smart list in collection
        let smartList = SmartEpisodeList(
            name: "Test Smart List",
            filter: EpisodeFilter()
        )
        await filterManager.createSmartList(smartList)
        
        // When: Deleting smart list
        await filterManager.deleteSmartList(id: smartList.id)
        
        // Then: Should remove from smart lists
        XCTAssertFalse(filterManager.smartLists.contains { $0.id == smartList.id }, 
                      "Should remove smart list from collection")
        XCTAssertTrue(mockRepository.deleteSmartListCalled, "Should delete smart list from repository")
    }
}

// MARK: - Mock Repository

@preconcurrency final class MockEpisodeFilterRepository: EpisodeFilterRepository, @unchecked Sendable {
    var saveGlobalPreferencesCalled = false
    var savePodcastFilterCalled = false
    var saveSmartListCalled = false
    var deleteSmartListCalled = false
    
    var lastSavedPodcastId: String?
    var lastSavedPodcastFilter: EpisodeFilter?
    
    private var globalPreferences: GlobalFilterPreferences?
    private var podcastFilters: [String: EpisodeFilter] = [:]
    private var smartLists: [SmartEpisodeList] = []
    
    func saveGlobalPreferences(_ preferences: GlobalFilterPreferences) async throws {
        saveGlobalPreferencesCalled = true
        globalPreferences = preferences
    }
    
    func loadGlobalPreferences() async throws -> GlobalFilterPreferences? {
        return globalPreferences
    }
    
    func savePodcastFilter(podcastId: String, filter: EpisodeFilter) async throws {
        savePodcastFilterCalled = true
        lastSavedPodcastId = podcastId
        lastSavedPodcastFilter = filter
        podcastFilters[podcastId] = filter
    }
    
    func loadPodcastFilter(podcastId: String) async throws -> EpisodeFilter? {
        return podcastFilters[podcastId]
    }
    
    func saveSmartList(_ smartList: SmartEpisodeList) async throws {
        saveSmartListCalled = true
        smartLists.removeAll { $0.id == smartList.id }
        smartLists.append(smartList)
    }
    
    func loadSmartLists() async throws -> [SmartEpisodeList] {
        return smartLists
    }
    
    func deleteSmartList(id: String) async throws {
        deleteSmartListCalled = true
        smartLists.removeAll { $0.id == id }
    }
}

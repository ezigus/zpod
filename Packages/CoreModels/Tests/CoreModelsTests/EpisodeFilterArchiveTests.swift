import XCTest
@testable import CoreModels

final class EpisodeFilterArchiveTests: XCTestCase {
    
    var service: DefaultEpisodeFilterService!
    
    override func setUp() async throws {
        try await super.setUp()
        service = DefaultEpisodeFilterService()
    }
    
    // MARK: - Helper Methods
    
    private func createEpisode(
        id: String,
        title: String,
        isArchived: Bool = false,
        isPlayed: Bool = false,
        pubDate: Date? = nil
    ) -> Episode {
        Episode(
            id: id,
            title: title,
            podcastID: "podcast-1",
            isPlayed: isPlayed,
            pubDate: pubDate,
            isArchived: isArchived
        )
    }
    
    // MARK: - Filter Preset Tests
    
    func testArchivedFilterPresetExists() {
        let presets = EpisodeFilterPreset.builtInPresets
        let archivedPreset = presets.first { $0.id == "archived" }
        
        XCTAssertNotNil(archivedPreset)
        XCTAssertEqual(archivedPreset?.name, "Archived Episodes")
        XCTAssertTrue(archivedPreset?.isBuiltIn ?? false)
        
        // Verify filter criteria
        let filter = archivedPreset?.filter
        XCTAssertEqual(filter?.conditions.count, 1)
        XCTAssertEqual(filter?.conditions.first?.criteria, .archived)
        XCTAssertFalse(filter?.conditions.first?.isNegated ?? true)
    }
    
    // MARK: - Default Filter Exclusion Tests
    
    func testFilterAndSort_ExcludesArchivedByDefault() async {
        let episodes = [
            createEpisode(id: "1", title: "Active 1", isArchived: false),
            createEpisode(id: "2", title: "Archived 1", isArchived: true),
            createEpisode(id: "3", title: "Active 2", isArchived: false),
            createEpisode(id: "4", title: "Archived 2", isArchived: true)
        ]
        
        // Empty filter should exclude archived episodes
        let emptyFilter = EpisodeFilter()
        let filtered = await service.filterAndSort(episodes: episodes, using: emptyFilter)
        
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains { $0.id == "1" })
        XCTAssertTrue(filtered.contains { $0.id == "3" })
        XCTAssertFalse(filtered.contains { $0.id == "2" })
        XCTAssertFalse(filtered.contains { $0.id == "4" })
    }
    
    func testFilterAndSort_IncludesArchivedWhenExplicitlyFiltered() async {
        let episodes = [
            createEpisode(id: "1", title: "Active", isArchived: false),
            createEpisode(id: "2", title: "Archived 1", isArchived: true),
            createEpisode(id: "3", title: "Archived 2", isArchived: true)
        ]
        
        // Filter explicitly for archived episodes
        let archivedFilter = EpisodeFilter(
            conditions: [EpisodeFilterCondition(criteria: .archived)]
        )
        let filtered = await service.filterAndSort(episodes: episodes, using: archivedFilter)
        
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains { $0.id == "2" })
        XCTAssertTrue(filtered.contains { $0.id == "3" })
        XCTAssertFalse(filtered.contains { $0.id == "1" })
    }
    
    func testFilterAndSort_WithOtherCriteria() async {
        let episodes = [
            createEpisode(id: "1", title: "Played Active", isArchived: false, isPlayed: true),
            createEpisode(id: "2", title: "Unplayed Active", isArchived: false, isPlayed: false),
            createEpisode(id: "3", title: "Played Archived", isArchived: true, isPlayed: true),
            createEpisode(id: "4", title: "Unplayed Archived", isArchived: true, isPlayed: false)
        ]
        
        // Filter for unplayed - should exclude archived
        let unplayedFilter = EpisodeFilter(
            conditions: [EpisodeFilterCondition(criteria: .unplayed)]
        )
        let filtered = await service.filterAndSort(episodes: episodes, using: unplayedFilter)
        
        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered.contains { $0.id == "2" })
    }
    
    func testFilterAndSort_NegatedArchivedCriteria() async {
        let episodes = [
            createEpisode(id: "1", title: "Active", isArchived: false),
            createEpisode(id: "2", title: "Archived", isArchived: true)
        ]
        
        // Filter with "not archived" - should only show active (but that's the default anyway)
        let notArchivedFilter = EpisodeFilter(
            conditions: [EpisodeFilterCondition(criteria: .archived, isNegated: true)]
        )
        let filtered = await service.filterAndSort(episodes: episodes, using: notArchivedFilter)
        
        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered.contains { $0.id == "1" })
    }
    
    // MARK: - Search Exclusion Tests
    
    func testSearchEpisodes_ExcludesArchivedByDefault() async {
        let episodes = [
            createEpisode(id: "1", title: "Test Active", isArchived: false),
            createEpisode(id: "2", title: "Test Archived", isArchived: true),
            createEpisode(id: "3", title: "Another Active", isArchived: false)
        ]
        
        let results = await service.searchEpisodes(
            episodes,
            query: "Test",
            filter: nil,
            includeArchived: false
        )
        
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains { $0.id == "1" })
        XCTAssertFalse(results.contains { $0.id == "2" })
    }
    
    func testSearchEpisodes_IncludesArchivedWhenRequested() async {
        let episodes = [
            createEpisode(id: "1", title: "Test Active", isArchived: false),
            createEpisode(id: "2", title: "Test Archived", isArchived: true),
            createEpisode(id: "3", title: "Another Active", isArchived: false)
        ]
        
        let results = await service.searchEpisodes(
            episodes,
            query: "Test",
            filter: nil,
            includeArchived: true
        )
        
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.id == "1" })
        XCTAssertTrue(results.contains { $0.id == "2" })
    }
    
    func testSearchEpisodesAdvanced_ExcludesArchivedByDefault() async {
        let episodes = [
            createEpisode(id: "1", title: "Search Term Active", isArchived: false),
            createEpisode(id: "2", title: "Search Term Archived", isArchived: true)
        ]
        
        let query = EpisodeSearchQuery(text: "Search Term")
        let results = await service.searchEpisodesAdvanced(
            episodes,
            query: query,
            filter: nil,
            includeArchived: false
        )
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.episode.id, "1")
    }
    
    func testSearchEpisodesAdvanced_IncludesArchivedWhenRequested() async {
        let episodes = [
            createEpisode(id: "1", title: "Search Term Active", isArchived: false),
            createEpisode(id: "2", title: "Search Term Archived", isArchived: true)
        ]
        
        let query = EpisodeSearchQuery(text: "Search Term")
        let results = await service.searchEpisodesAdvanced(
            episodes,
            query: query,
            filter: nil,
            includeArchived: true
        )
        
        XCTAssertEqual(results.count, 2)
    }
    
    // MARK: - Complex Filter Scenarios
    
    func testFilterAndSort_ArchivedWithANDLogic() async {
        let episodes = [
            createEpisode(id: "1", title: "Played Active", isArchived: false, isPlayed: true),
            createEpisode(id: "2", title: "Unplayed Active", isArchived: false, isPlayed: false),
            createEpisode(id: "3", title: "Played Archived", isArchived: true, isPlayed: true),
            createEpisode(id: "4", title: "Unplayed Archived", isArchived: true, isPlayed: false)
        ]
        
        // Filter for archived AND unplayed
        let filter = EpisodeFilter(
            conditions: [
                EpisodeFilterCondition(criteria: .archived),
                EpisodeFilterCondition(criteria: .unplayed)
            ],
            logic: .and
        )
        let filtered = await service.filterAndSort(episodes: episodes, using: filter)
        
        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered.contains { $0.id == "4" })
    }
    
    func testFilterAndSort_ArchivedWithORLogic() async {
        let episodes = [
            createEpisode(id: "1", title: "Played Active", isArchived: false, isPlayed: true),
            createEpisode(id: "2", title: "Unplayed Active", isArchived: false, isPlayed: false),
            createEpisode(id: "3", title: "Played Archived", isArchived: true, isPlayed: true),
            createEpisode(id: "4", title: "Unplayed Archived", isArchived: true, isPlayed: false)
        ]
        
        // Filter for archived OR unplayed
        let filter = EpisodeFilter(
            conditions: [
                EpisodeFilterCondition(criteria: .archived),
                EpisodeFilterCondition(criteria: .unplayed)
            ],
            logic: .or
        )
        let filtered = await service.filterAndSort(episodes: episodes, using: filter)
        
        // Should include: archived episodes (3, 4) AND unplayed active (2)
        XCTAssertEqual(filtered.count, 3)
        XCTAssertTrue(filtered.contains { $0.id == "2" })
        XCTAssertTrue(filtered.contains { $0.id == "3" })
        XCTAssertTrue(filtered.contains { $0.id == "4" })
    }
    
    // MARK: - Smart List Tests
    
    func testUpdateSmartList_WithArchivedFilter() async {
        let episodes = [
            createEpisode(id: "1", title: "Active", isArchived: false),
            createEpisode(id: "2", title: "Archived 1", isArchived: true),
            createEpisode(id: "3", title: "Archived 2", isArchived: true)
        ]
        
        let smartList = SmartEpisodeList(
            name: "Archived Episodes",
            filter: EpisodeFilter(
                conditions: [EpisodeFilterCondition(criteria: .archived)]
            )
        )
        
        let result = await service.updateSmartList(smartList, allEpisodes: episodes)
        
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.id == "2" })
        XCTAssertTrue(result.contains { $0.id == "3" })
    }
    
    func testUpdateSmartList_WithoutArchivedFilter() async {
        let episodes = [
            createEpisode(id: "1", title: "Played Active", isArchived: false, isPlayed: true),
            createEpisode(id: "2", title: "Played Archived", isArchived: true, isPlayed: true),
            createEpisode(id: "3", title: "Unplayed Active", isArchived: false, isPlayed: false)
        ]
        
        let smartList = SmartEpisodeList(
            name: "Played Episodes",
            filter: EpisodeFilter(
                conditions: [EpisodeFilterCondition(criteria: .unplayed, isNegated: true)]
            )
        )
        
        let result = await service.updateSmartList(smartList, allEpisodes: episodes)
        
        // Should exclude archived episode even though it matches the played criteria
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.contains { $0.id == "1" })
    }
}

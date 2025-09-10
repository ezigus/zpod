import XCTest
import Foundation
@testable import CoreModels

// MARK: - Episode Filtering Tests

final class EpisodeFilteringTests: XCTestCase {
    
    private var filterService: DefaultEpisodeFilterService!
    private var testEpisodes: [Episode]!
    
    override func setUp() async throws {
        try await super.setUp()
        
        filterService = DefaultEpisodeFilterService()
        testEpisodes = createTestEpisodes()
    }
    
    override func tearDown() async throws {
        filterService = nil
        testEpisodes = nil
        try await super.tearDown()
    }
    
    // MARK: - Filter Condition Tests
    
    func testEpisodeMatches_UnplayedFilter() async {
        // Given: Episode filter condition for unplayed episodes
        let condition = EpisodeFilterCondition(criteria: .unplayed)
        
        // When: Testing against played and unplayed episodes
        let unplayedEpisode = testEpisodes[0] // Episode 1 is unplayed
        let playedEpisode = testEpisodes[2] // Episode 3 is played
        
        // Then: Should match correctly
        let unplayedMatches = await filterService.episodeMatches(unplayedEpisode, condition: condition)
        let playedMatches = await filterService.episodeMatches(playedEpisode, condition: condition)
        
        XCTAssertTrue(unplayedMatches, "Unplayed episode should match unplayed filter")
        XCTAssertFalse(playedMatches, "Played episode should not match unplayed filter")
    }
    
    func testEpisodeMatches_FavoritedFilter() async {
        // Given: Episode filter condition for favorited episodes
        let condition = EpisodeFilterCondition(criteria: .favorited)
        
        // When: Testing favorited episode
        let favoritedEpisode = testEpisodes[3] // Episode 4 is favorited
        let nonFavoritedEpisode = testEpisodes[0] // Episode 1 is not favorited
        
        // Then: Should match correctly
        let favoritedMatches = await filterService.episodeMatches(favoritedEpisode, condition: condition)
        let nonFavoritedMatches = await filterService.episodeMatches(nonFavoritedEpisode, condition: condition)
        
        XCTAssertTrue(favoritedMatches, "Favorited episode should match favorited filter")
        XCTAssertFalse(nonFavoritedMatches, "Non-favorited episode should not match favorited filter")
    }
    
    func testEpisodeMatches_InProgressFilter() async {
        // Given: Episode filter condition for in-progress episodes
        let condition = EpisodeFilterCondition(criteria: .inProgress)
        
        // When: Testing in-progress episode
        let inProgressEpisode = testEpisodes[1] // Episode 2 is in progress
        let unplayedEpisode = testEpisodes[0] // Episode 1 is unplayed
        let playedEpisode = testEpisodes[2] // Episode 3 is played
        
        // Then: Should match correctly
        let inProgressMatches = await filterService.episodeMatches(inProgressEpisode, condition: condition)
        let unplayedMatches = await filterService.episodeMatches(unplayedEpisode, condition: condition)
        let playedMatches = await filterService.episodeMatches(playedEpisode, condition: condition)
        
        XCTAssertTrue(inProgressMatches, "In-progress episode should match in-progress filter")
        XCTAssertFalse(unplayedMatches, "Unplayed episode should not match in-progress filter")
        XCTAssertFalse(playedMatches, "Played episode should not match in-progress filter")
    }
    
    func testEpisodeMatches_NegatedCondition() async {
        // Given: Negated episode filter condition
        let condition = EpisodeFilterCondition(criteria: .unplayed, isNegated: true)
        
        // When: Testing against episodes
        let unplayedEpisode = testEpisodes[0] // Episode 1 is unplayed
        let playedEpisode = testEpisodes[2] // Episode 3 is played
        
        // Then: Should match negated condition
        let unplayedMatches = await filterService.episodeMatches(unplayedEpisode, condition: condition)
        let playedMatches = await filterService.episodeMatches(playedEpisode, condition: condition)
        
        XCTAssertFalse(unplayedMatches, "Unplayed episode should not match negated unplayed filter")
        XCTAssertTrue(playedMatches, "Played episode should match negated unplayed filter")
    }
    
    // MARK: - Sorting Tests
    
    func testSortEpisodes_ByPubDateNewest() async {
        // Given: Episodes with different publication dates
        // When: Sorting by newest publication date
        let sortedEpisodes = await filterService.sortEpisodes(testEpisodes, by: .pubDateNewest)
        
        // Then: Should be sorted newest first
        XCTAssertEqual(sortedEpisodes[0].id, "ep4", "Newest episode should be first")
        XCTAssertEqual(sortedEpisodes[1].id, "ep3", "Second newest should be second")
        XCTAssertEqual(sortedEpisodes[2].id, "ep2", "Third newest should be third")
        XCTAssertEqual(sortedEpisodes[3].id, "ep1", "Oldest should be last")
    }
    
    func testSortEpisodes_ByPubDateOldest() async {
        // Given: Episodes with different publication dates
        // When: Sorting by oldest publication date
        let sortedEpisodes = await filterService.sortEpisodes(testEpisodes, by: .pubDateOldest)
        
        // Then: Should be sorted oldest first
        XCTAssertEqual(sortedEpisodes[0].id, "ep1", "Oldest episode should be first")
        XCTAssertEqual(sortedEpisodes[1].id, "ep2", "Second oldest should be second")
        XCTAssertEqual(sortedEpisodes[2].id, "ep3", "Third oldest should be third")
        XCTAssertEqual(sortedEpisodes[3].id, "ep4", "Newest should be last")
    }
    
    func testSortEpisodes_ByDuration() async {
        // Given: Episodes with different durations
        // When: Sorting by duration
        let sortedEpisodes = await filterService.sortEpisodes(testEpisodes, by: .duration)
        
        // Then: Should be sorted by duration (shortest first)
        XCTAssertTrue(sortedEpisodes[0].duration! <= sortedEpisodes[1].duration!, "First episode should have shortest or equal duration")
        XCTAssertTrue(sortedEpisodes[1].duration! <= sortedEpisodes[2].duration!, "Duration should be in ascending order")
    }
    
    func testSortEpisodes_ByTitle() async {
        // Given: Episodes with different titles
        // When: Sorting by title
        let sortedEpisodes = await filterService.sortEpisodes(testEpisodes, by: .title)
        
        // Then: Should be sorted alphabetically
        for i in 0..<sortedEpisodes.count-1 {
            let currentTitle = sortedEpisodes[i].title
            let nextTitle = sortedEpisodes[i+1].title
            XCTAssertTrue(currentTitle.localizedCaseInsensitiveCompare(nextTitle) != .orderedDescending, 
                         "Episodes should be sorted alphabetically by title")
        }
    }
    
    // MARK: - Filter Combination Tests
    
    func testFilterAndSort_ANDLogic() async {
        // Given: Filter with multiple conditions using AND logic
        let conditions = [
            EpisodeFilterCondition(criteria: .unplayed),
            EpisodeFilterCondition(criteria: .downloaded)
        ]
        let filter = EpisodeFilter(conditions: conditions, logic: .and, sortBy: .title)
        
        // When: Applying filter
        let filteredEpisodes = await filterService.filterAndSort(episodes: testEpisodes, using: filter)
        
        // Then: Should only include episodes matching ALL conditions
        for episode in filteredEpisodes {
            XCTAssertFalse(episode.isPlayed, "All episodes should be unplayed")
            XCTAssertTrue(episode.isDownloaded, "All episodes should be downloaded")
        }
    }
    
    func testFilterAndSort_ORLogic() async {
        // Given: Filter with multiple conditions using OR logic
        let conditions = [
            EpisodeFilterCondition(criteria: .favorited),
            EpisodeFilterCondition(criteria: .bookmarked)
        ]
        let filter = EpisodeFilter(conditions: conditions, logic: .or, sortBy: .title)
        
        // When: Applying filter
        let filteredEpisodes = await filterService.filterAndSort(episodes: testEpisodes, using: filter)
        
        // Then: Should include episodes matching ANY condition
        for episode in filteredEpisodes {
            let matchesCondition = episode.isFavorited || episode.isBookmarked
            XCTAssertTrue(matchesCondition, "Episode should match at least one condition")
        }
    }
    
    func testFilterAndSort_EmptyFilter() async {
        // Given: Empty filter
        let filter = EpisodeFilter()
        
        // When: Applying filter
        let filteredEpisodes = await filterService.filterAndSort(episodes: testEpisodes, using: filter)
        
        // Then: Should return all episodes sorted by default
        XCTAssertEqual(filteredEpisodes.count, testEpisodes.count, "Empty filter should return all episodes")
    }
    
    // MARK: - Search Tests
    
    func testSearchEpisodes_ByTitle() async {
        // Given: Search query for episode title
        let query = "Swift"
        
        // When: Searching episodes
        let searchResults = await filterService.searchEpisodes(testEpisodes, query: query)
        
        // Then: Should return episodes with matching titles
        XCTAssertTrue(searchResults.count > 0, "Should find episodes with matching titles")
        for episode in searchResults {
            XCTAssertTrue(episode.title.localizedCaseInsensitiveContains(query), 
                         "Episode title should contain search query")
        }
    }
    
    func testSearchEpisodes_ByDescription() async {
        // Given: Search query for episode description
        let query = "programming"
        
        // When: Searching episodes
        let searchResults = await filterService.searchEpisodes(testEpisodes, query: query)
        
        // Then: Should return episodes with matching descriptions
        for episode in searchResults {
            let titleMatch = episode.title.localizedCaseInsensitiveContains(query)
            let descriptionMatch = episode.description?.localizedCaseInsensitiveContains(query) ?? false
            XCTAssertTrue(titleMatch || descriptionMatch, 
                         "Episode should match in title or description")
        }
    }
    
    func testSearchEpisodes_WithFilter() async {
        // Given: Search query with additional filter
        let query = "Episode"
        let filter = EpisodeFilter(
            conditions: [EpisodeFilterCondition(criteria: .unplayed)],
            logic: .and,
            sortBy: .title
        )
        
        // When: Searching with filter
        let searchResults = await filterService.searchEpisodes(testEpisodes, query: query, filter: filter)
        
        // Then: Should return episodes matching both search and filter
        for episode in searchResults {
            let titleMatch = episode.title.localizedCaseInsensitiveContains(query)
            let descriptionMatch = episode.description?.localizedCaseInsensitiveContains(query) ?? false
            XCTAssertTrue(titleMatch || descriptionMatch, "Episode should match search query")
            XCTAssertFalse(episode.isPlayed, "Episode should also match filter criteria")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestEpisodes() -> [Episode] {
        let baseDate = Date()
        
        return [
            Episode(
                id: "ep1",
                title: "Episode 1: Introduction to Swift",
                podcastID: "podcast1",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: Calendar.current.date(byAdding: .day, value: -3, to: baseDate),
                duration: 1800,
                description: "Introduction to Swift programming language.",
                downloadStatus: .downloaded
            ),
            Episode(
                id: "ep2",
                title: "Episode 2: SwiftUI Fundamentals",
                podcastID: "podcast1",
                playbackPosition: 300,
                isPlayed: false,
                pubDate: Calendar.current.date(byAdding: .day, value: -2, to: baseDate),
                duration: 2400,
                description: "Learn about SwiftUI programming fundamentals.",
                downloadStatus: .notDownloaded
            ),
            Episode(
                id: "ep3",
                title: "Episode 3: Advanced Concepts",
                podcastID: "podcast1",
                playbackPosition: 0,
                isPlayed: true,
                pubDate: Calendar.current.date(byAdding: .day, value: -1, to: baseDate),
                duration: 3000,
                description: "Advanced programming concepts and patterns.",
                downloadStatus: .downloaded
            ),
            Episode(
                id: "ep4",
                title: "Episode 4: Best Practices",
                podcastID: "podcast1",
                playbackPosition: 0,
                isPlayed: false,
                pubDate: baseDate,
                duration: 2700,
                description: "Best practices for development.",
                downloadStatus: .notDownloaded,
                isFavorited: true,
                isBookmarked: true,
                rating: 5
            )
        ]
    }
}
import XCTest
@testable import RecommendationDomain
@testable import CoreModels
import TestSupport

/// Comprehensive unit tests for baseline recommendation service
final class BaselineRecommendationServiceTests: XCTestCase {
    
    // MARK: - Test Data
    private var service: BaselineRecommendationService!
    private var criteria: RecommendationCriteria!
    /// Fixed date used consistently throughout tests for deterministic date-based testing
    private let testDate = Date() // Use current date for deterministic relative testing
    
    override func setUp() async throws {
        try await super.setUp()
        service = BaselineRecommendationService()
        criteria = RecommendationCriteria(
            maxRecommendations: 10,
            categoryFrequencyWeight: 0.5,
            recencyWeight: 0.3,
            popularityWeight: 0.2,
            excludePlayedEpisodes: true,
            minimumScore: 0.1
        )
    }
    
    // MARK: - Category Weighting Tests
    
    func testAcceptanceCriteria1_CategoryWeighting() async {
        // Given: User has play history with specific category preferences
        let techPodcast = createTechPodcast()
        let newsPodcast = createNewsPodcast()
        let podcasts = [techPodcast, newsPodcast]
        
        let playHistory = [
            createPlaybackEntry(episodeId: "tech-ep-1", podcastId: techPodcast.id, playedAt: testDate),
            createPlaybackEntry(episodeId: "tech-ep-2", podcastId: techPodcast.id, playedAt: testDate),
            createPlaybackEntry(episodeId: "news-ep-1", podcastId: newsPodcast.id, playedAt: testDate)
        ]
        
        // When: Generating recommendations
        let recommendations = await service.generateRecommendations(
            criteria: criteria,
            podcasts: podcasts,
            playHistory: playHistory
        )
        
        // Then: Technology category should be weighted higher than News
        let techRecommendations = recommendations.filter { rec in
            techPodcast.episodes.contains { $0.id == rec.targetId }
        }
        let newsRecommendations = recommendations.filter { rec in
            newsPodcast.episodes.contains { $0.id == rec.targetId }
        }
        
        XCTAssertGreaterThan(techRecommendations.count, newsRecommendations.count,
                           "Technology episodes should be recommended more due to higher play frequency")
        
        // Verify deterministic ordering
        let sortedByScore = recommendations.sorted { $0.score > $1.score }
        XCTAssertEqual(recommendations, sortedByScore, "Recommendations should be sorted by score in descending order")
    }
    
    func testAcceptanceCriteria2_ExcludePlayedEpisodes() async {
        // Given: User has played some episodes completely
        let podcast = createTechPodcast()
        let podcasts = [podcast]
        
        let playHistory = [
            createPlaybackEntry(episodeId: "tech-ep-1", podcastId: podcast.id, completed: true),
            createPlaybackEntry(episodeId: "tech-ep-2", podcastId: podcast.id, completed: false)
        ]
        
        // When: Generating recommendations with excludePlayedEpisodes = true
        let recommendations = await service.generateRecommendations(
            criteria: criteria,
            podcasts: podcasts,
            playHistory: playHistory
        )
        
        // Then: Should exclude completely played episodes
        let recommendedEpisodeIds = Set(recommendations.map { $0.targetId })
        XCTAssertFalse(recommendedEpisodeIds.contains("tech-ep-1"), 
                      "Should exclude completed episodes")
        XCTAssertTrue(recommendedEpisodeIds.contains("tech-ep-3") || recommendedEpisodeIds.contains("tech-ep-4"),
                     "Should include unplayed episodes")
    }
    
    func testAcceptanceCriteria3_RecencyPreference() async {
        // Given: Podcast with episodes of different ages
        let podcast = createPodcastWithVariedEpisodeDates()
        let podcasts = [podcast]
        let playHistory = [createPlaybackEntry(episodeId: "old-ep", podcastId: podcast.id)]
        
        // When: Generating recommendations
        let recommendations = await service.generateRecommendations(
            criteria: criteria,
            podcasts: podcasts,
            playHistory: playHistory
        )
        
        // Then: Newer episodes should have higher scores
        guard recommendations.count >= 2 else {
            XCTFail("Should have multiple recommendations to compare")
            return
        }
        
        let recentEpisodeRec = recommendations.first { $0.targetId == "recent-ep" }
        let oldEpisodeRec = recommendations.first { $0.targetId == "very-old-ep" }
        
        if let recentRec = recentEpisodeRec, let oldRec = oldEpisodeRec {
            XCTAssertGreaterThan(recentRec.score, oldRec.score,
                               "Recent episodes should have higher scores")
        }
    }
    
    func testAcceptanceCriteria4_ReasonStringGeneration() async {
        // Given: User with category preferences
        let techPodcast = createTechPodcast()
        let podcasts = [techPodcast]
        let playHistory = [createPlaybackEntry(episodeId: "tech-ep-1", podcastId: techPodcast.id)]
        
        // When: Generating recommendations
        let recommendations = await service.generateRecommendations(
            criteria: criteria,
            podcasts: podcasts,
            playHistory: playHistory
        )
        
        // Then: Should have meaningful reason strings
        XCTAssertFalse(recommendations.isEmpty, "Should have recommendations")
        
        let firstRec = recommendations.first!
        XCTAssertFalse(firstRec.reason.primary.isEmpty, "Should have primary reason")
        XCTAssertFalse(firstRec.reason.displayText.isEmpty, "Should have display text")
        
        // Should contain category-based reasoning
        let displayText = firstRec.reason.displayText
        XCTAssertTrue(displayText.contains("Technology") || displayText.contains("interest"),
                     "Reason should mention category or interest: \(displayText)")
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyPlayHistory_ReturnsRecommendations() async {
        // Given: No play history
        let podcasts = [createTechPodcast()]
        let playHistory: [PlaybackHistoryEntry] = []
        
        // When: Generating recommendations
        let recommendations = await service.generateRecommendations(
            criteria: criteria,
            podcasts: podcasts,
            playHistory: playHistory
        )
        
        // Then: Should still return recommendations based on recency and popularity
        XCTAssertFalse(recommendations.isEmpty, "Should provide recommendations even without play history")
    }
    
    func testNoPodcasts_ReturnsEmptyRecommendations() async {
        // Given: No subscribed podcasts
        let podcasts: [Podcast] = []
        let playHistory: [PlaybackHistoryEntry] = []
        
        // When: Generating recommendations
        let recommendations = await service.generateRecommendations(
            criteria: criteria,
            podcasts: podcasts,
            playHistory: playHistory
        )
        
        // Then: Should return empty array
        XCTAssertTrue(recommendations.isEmpty, "Should return no recommendations without podcasts")
    }
    
    func testAllEpisodesPlayed_ReturnsEmptyWhenExcluding() async {
        // Given: All episodes are played
        let podcast = createTechPodcast()
        let podcasts = [podcast]
        let playHistory = podcast.episodes.map { episode in
            createPlaybackEntry(episodeId: episode.id, podcastId: podcast.id, completed: true)
        }
        
        // When: Generating recommendations with excludePlayedEpisodes = true
        let recommendations = await service.generateRecommendations(
            criteria: criteria,
            podcasts: podcasts,
            playHistory: playHistory
        )
        
        // Then: Should return empty array
        XCTAssertTrue(recommendations.isEmpty, "Should return no recommendations when all episodes are played and excluded")
    }
    
    func testDeterministicOrdering_SameInputsSameOutput() async {
        // Given: Fixed test data
        let podcasts = [createTechPodcast(), createNewsPodcast()]
        let playHistory = [createPlaybackEntry(episodeId: "tech-ep-1", podcastId: "tech-podcast")]
        
        // When: Generating recommendations multiple times
        let recommendations1 = await service.generateRecommendations(
            criteria: criteria,
            podcasts: podcasts,
            playHistory: playHistory
        )
        
        let recommendations2 = await service.generateRecommendations(
            criteria: criteria,
            podcasts: podcasts,
            playHistory: playHistory
        )
        
        // Then: Results should be identical
        XCTAssertEqual(recommendations1.count, recommendations2.count, "Should return same number of recommendations")
        
        for (rec1, rec2) in zip(recommendations1, recommendations2) {
            XCTAssertEqual(rec1.targetId, rec2.targetId, "Should recommend same episodes in same order")
            XCTAssertEqual(rec1.score, rec2.score, accuracy: 0.001, "Should have same scores")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTechPodcast() -> Podcast {
        let episodes = [
            Episode(id: "tech-ep-1", title: "Swift 6 Concurrency", pubDate: testDate),
            Episode(id: "tech-ep-2", title: "iOS 18 Features", pubDate: testDate.addingTimeInterval(-86400)), // 1 day ago
            Episode(id: "tech-ep-3", title: "Xcode Tips", pubDate: testDate.addingTimeInterval(-172800)), // 2 days ago
            Episode(id: "tech-ep-4", title: "SwiftUI Updates", pubDate: testDate.addingTimeInterval(-259200)) // 3 days ago
        ]
        
        return Podcast(
            id: "tech-podcast",
            title: "Tech Talk",
            author: "Tech Author",
            description: "Technology podcast",
            feedURL: URL(string: "https://example.com/tech.xml")!,
            categories: ["Technology", "Programming"],
            episodes: episodes,
            isSubscribed: true
        )
    }
    
    private func createNewsPodcast() -> Podcast {
        let episodes = [
            Episode(id: "news-ep-1", title: "Daily News", pubDate: testDate),
            Episode(id: "news-ep-2", title: "Weekly Update", pubDate: testDate.addingTimeInterval(-86400))
        ]
        
        return Podcast(
            id: "news-podcast",
            title: "Daily News",
            author: "News Author",
            description: "News podcast",
            feedURL: URL(string: "https://example.com/news.xml")!,
            categories: ["News", "Current Events"],
            episodes: episodes,
            isSubscribed: true
        )
    }
    
    private func createPodcastWithVariedEpisodeDates() -> Podcast {
        let episodes = [
            Episode(id: "recent-ep", title: "Recent Episode", pubDate: testDate),
            Episode(id: "week-old-ep", title: "Week Old", pubDate: testDate.addingTimeInterval(-7 * 86400)),
            Episode(id: "month-old-ep", title: "Month Old", pubDate: testDate.addingTimeInterval(-30 * 86400)),
            Episode(id: "very-old-ep", title: "Very Old", pubDate: testDate.addingTimeInterval(-90 * 86400))
        ]
        
        return Podcast(
            id: "varied-podcast",
            title: "Varied Episodes",
            author: "Author",
            description: "Test podcast",
            feedURL: URL(string: "https://example.com/varied.xml")!,
            categories: ["Technology"],
            episodes: episodes,
            isSubscribed: true
        )
    }
    
    private func createPlaybackEntry(
        episodeId: String,
        podcastId: String,
        playedAt: Date? = nil, // Will use testDate if nil
        duration: TimeInterval = 1800,
        completed: Bool = true
    ) -> PlaybackHistoryEntry {
        PlaybackHistoryEntry(
            episodeId: episodeId,
            podcastId: podcastId,
            playedAt: playedAt ?? testDate,
            duration: duration,
            completed: completed
        )
    }
}
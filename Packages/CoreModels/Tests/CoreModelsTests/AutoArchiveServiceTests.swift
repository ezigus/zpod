import XCTest
@testable import CoreModels

final class AutoArchiveServiceTests: XCTestCase {
    
    var service: DefaultAutoArchiveService!
    
    override func setUp() async throws {
        try await super.setUp()
        service = DefaultAutoArchiveService()
    }
    
    // MARK: - Helper Methods
    
    private func createEpisode(
        id: String,
        isPlayed: Bool = false,
        isArchived: Bool = false,
        isFavorited: Bool = false,
        isBookmarked: Bool = false,
        downloadStatus: EpisodeDownloadStatus = .notDownloaded,
        pubDate: Date? = nil
    ) -> Episode {
        Episode(
            id: id,
            title: "Episode \(id)",
            podcastID: "podcast-1",
            isPlayed: isPlayed,
            pubDate: pubDate,
            downloadStatus: downloadStatus,
            isFavorited: isFavorited,
            isBookmarked: isBookmarked,
            isArchived: isArchived
        )
    }

    // MARK: - shouldArchive Tests
    
    func testShouldArchive_PlayedAndOlderThanDays() async {
        let thirtyOneDaysAgo = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let twentyNineDaysAgo = Calendar.current.date(byAdding: .day, value: -29, to: Date())!
        
        let rule = AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: 30
        )
        
        // Played and old enough - should archive
        let oldPlayed = createEpisode(id: "1", isPlayed: true, pubDate: thirtyOneDaysAgo)
        XCTAssertTrue(service.shouldArchive(oldPlayed, basedOn: rule))
        
        // Played but not old enough - should not archive
        let recentPlayed = createEpisode(id: "2", isPlayed: true, pubDate: twentyNineDaysAgo)
        XCTAssertFalse(service.shouldArchive(recentPlayed, basedOn: rule))
        
        // Old enough but not played - should not archive
        let oldUnplayed = createEpisode(id: "3", isPlayed: false, pubDate: thirtyOneDaysAgo)
        XCTAssertFalse(service.shouldArchive(oldUnplayed, basedOn: rule))
    }
    
    func testShouldArchive_PlayedRegardlessOfAge() async {
        let rule = AutoArchiveRule(condition: .playedRegardlessOfAge)
        
        // Played - should archive
        let played = createEpisode(id: "1", isPlayed: true)
        XCTAssertTrue(service.shouldArchive(played, basedOn: rule))
        
        // Not played - should not archive
        let unplayed = createEpisode(id: "2", isPlayed: false)
        XCTAssertFalse(service.shouldArchive(unplayed, basedOn: rule))
    }
    
    func testShouldArchive_OlderThanDays() async {
        let hundredDaysAgo = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let eightyDaysAgo = Calendar.current.date(byAdding: .day, value: -80, to: Date())!
        
        let rule = AutoArchiveRule(
            condition: .olderThanDays,
            daysOld: 90
        )
        
        // Old enough - should archive regardless of play status
        let oldEpisode = createEpisode(id: "1", isPlayed: false, pubDate: hundredDaysAgo)
        XCTAssertTrue(service.shouldArchive(oldEpisode, basedOn: rule))
        
        // Not old enough - should not archive
        let recentEpisode = createEpisode(id: "2", isPlayed: true, pubDate: eightyDaysAgo)
        XCTAssertFalse(service.shouldArchive(recentEpisode, basedOn: rule))
    }
    
    func testShouldArchive_DownloadedAndPlayed() async {
        let rule = AutoArchiveRule(condition: .downloadedAndPlayed)
        
        // Downloaded and played - should archive
        let downloadedPlayed = createEpisode(
            id: "1",
            isPlayed: true,
            downloadStatus: .downloaded
        )
        XCTAssertTrue(service.shouldArchive(downloadedPlayed, basedOn: rule))
        
        // Downloaded but not played - should not archive
        let downloadedUnplayed = createEpisode(
            id: "2",
            isPlayed: false,
            downloadStatus: .downloaded
        )
        XCTAssertFalse(service.shouldArchive(downloadedUnplayed, basedOn: rule))
        
        // Played but not downloaded - should not archive
        let notDownloadedPlayed = createEpisode(
            id: "3",
            isPlayed: true,
            downloadStatus: .notDownloaded
        )
        XCTAssertFalse(service.shouldArchive(notDownloadedPlayed, basedOn: rule))
    }
    
    func testShouldArchive_ExcludeFavorites() async {
        let rule = AutoArchiveRule(
            condition: .playedRegardlessOfAge,
            excludeFavorites: true
        )
        
        // Played but favorited - should not archive
        let favoritedPlayed = createEpisode(id: "1", isPlayed: true, isFavorited: true)
        XCTAssertFalse(service.shouldArchive(favoritedPlayed, basedOn: rule))
        
        // Played and not favorited - should archive
        let regularPlayed = createEpisode(id: "2", isPlayed: true, isFavorited: false)
        XCTAssertTrue(service.shouldArchive(regularPlayed, basedOn: rule))
    }
    
    func testShouldArchive_ExcludeBookmarked() async {
        let rule = AutoArchiveRule(
            condition: .playedRegardlessOfAge,
            excludeBookmarked: true
        )
        
        // Played but bookmarked - should not archive
        let bookmarkedPlayed = createEpisode(id: "1", isPlayed: true, isBookmarked: true)
        XCTAssertFalse(service.shouldArchive(bookmarkedPlayed, basedOn: rule))
        
        // Played and not bookmarked - should archive
        let regularPlayed = createEpisode(id: "2", isPlayed: true, isBookmarked: false)
        XCTAssertTrue(service.shouldArchive(regularPlayed, basedOn: rule))
    }
    
    func testShouldArchive_AlreadyArchived() async {
        let rule = AutoArchiveRule(condition: .playedRegardlessOfAge)
        
        // Already archived - should not archive again
        let alreadyArchived = createEpisode(id: "1", isPlayed: true, isArchived: true)
        XCTAssertFalse(service.shouldArchive(alreadyArchived, basedOn: rule))
    }
    
    func testShouldArchive_DisabledRule() async {
        let rule = AutoArchiveRule(
            isEnabled: false,
            condition: .playedRegardlessOfAge
        )
        
        // Rule is disabled - should not archive
        let played = createEpisode(id: "1", isPlayed: true)
        XCTAssertFalse(service.shouldArchive(played, basedOn: rule))
    }
    
    func testShouldArchive_InvalidRule() async {
        let rule = AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: nil // Invalid - missing required parameter
        )
        
        // Rule is invalid - should not archive
        let episode = createEpisode(id: "1", isPlayed: true)
        XCTAssertFalse(service.shouldArchive(episode, basedOn: rule))
    }
    
    // MARK: - evaluateRules Tests
    
    func testEvaluateRules_MultipleRules() async {
        let thirtyOneDaysAgo = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        
        let rule1 = AutoArchiveRule(condition: .playedRegardlessOfAge)
        let rule2 = AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: 30
        )
        
        let episodes = [
            createEpisode(id: "1", isPlayed: true, pubDate: Date()), // Matches rule1
            createEpisode(id: "2", isPlayed: true, pubDate: thirtyOneDaysAgo), // Matches both
            createEpisode(id: "3", isPlayed: false, pubDate: thirtyOneDaysAgo), // Matches none
            createEpisode(id: "4", isPlayed: true, isFavorited: true) // Excluded by default
        ]
        
        let episodesToArchive = service.evaluateRules([rule1, rule2], forEpisodes: episodes)
        
        // Should return episodes 1 and 2 (3 doesn't match, 4 is favorited)
        XCTAssertEqual(episodesToArchive.count, 2)
        XCTAssertTrue(episodesToArchive.contains("1"))
        XCTAssertTrue(episodesToArchive.contains("2"))
        XCTAssertFalse(episodesToArchive.contains("3"))
        XCTAssertFalse(episodesToArchive.contains("4"))
    }
    
    func testEvaluateRules_EmptyRules() async {
        let episodes = [
            createEpisode(id: "1", isPlayed: true)
        ]
        
        let episodesToArchive = service.evaluateRules([], forEpisodes: episodes)
        
        XCTAssertTrue(episodesToArchive.isEmpty)
    }
    
    func testEvaluateRules_EmptyEpisodes() async {
        let rule = AutoArchiveRule(condition: .playedRegardlessOfAge)
        
        let episodesToArchive = service.evaluateRules([rule], forEpisodes: [])
        
        XCTAssertTrue(episodesToArchive.isEmpty)
    }
    
    // MARK: - evaluateForPodcast Tests
    
    func testEvaluateForPodcast_Enabled() async {
        let rule = AutoArchiveRule(condition: .playedRegardlessOfAge)
        let config = PodcastAutoArchiveConfig(
            podcastId: "podcast-1",
            rules: [rule],
            isEnabled: true
        )
        
        let episodes = [
            createEpisode(id: "1", isPlayed: true),
            createEpisode(id: "2", isPlayed: false)
        ]
        
        let episodesToArchive = service.evaluateForPodcast(config, episodes: episodes)
        
        XCTAssertEqual(episodesToArchive.count, 1)
        XCTAssertTrue(episodesToArchive.contains("1"))
    }
    
    func testEvaluateForPodcast_Disabled() async {
        let rule = AutoArchiveRule(condition: .playedRegardlessOfAge)
        let config = PodcastAutoArchiveConfig(
            podcastId: "podcast-1",
            rules: [rule],
            isEnabled: false
        )
        
        let episodes = [
            createEpisode(id: "1", isPlayed: true),
            createEpisode(id: "2", isPlayed: false)
        ]
        
        let episodesToArchive = service.evaluateForPodcast(config, episodes: episodes)
        
        XCTAssertTrue(episodesToArchive.isEmpty)
    }
    
    // MARK: - shouldRunAutoArchive Tests
    
    func testShouldRunAutoArchive_NeverRunBefore() async {
        let config = GlobalAutoArchiveConfig(
            isGlobalEnabled: true,
            lastRunAt: nil
        )
        
        XCTAssertTrue(service.shouldRunAutoArchive(config))
    }
    
    func testShouldRunAutoArchive_IntervalElapsed() async {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let config = GlobalAutoArchiveConfig(
            isGlobalEnabled: true,
            autoRunInterval: 1800, // 30 minutes
            lastRunAt: oneHourAgo
        )
        
        XCTAssertTrue(service.shouldRunAutoArchive(config))
    }
    
    func testShouldRunAutoArchive_IntervalNotElapsed() async {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let config = GlobalAutoArchiveConfig(
            isGlobalEnabled: true,
            autoRunInterval: 1800, // 30 minutes
            lastRunAt: fiveMinutesAgo
        )
        
        XCTAssertFalse(service.shouldRunAutoArchive(config))
    }
    
    func testShouldRunAutoArchive_GloballyDisabled() async {
        let config = GlobalAutoArchiveConfig(
            isGlobalEnabled: false,
            lastRunAt: nil
        )
        
        XCTAssertFalse(service.shouldRunAutoArchive(config))
    }
}

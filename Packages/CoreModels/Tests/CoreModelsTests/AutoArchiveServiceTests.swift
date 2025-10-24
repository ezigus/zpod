import XCTest
@testable import CoreModels

final class AutoArchiveServiceTests: XCTestCase {
    
    var service: DefaultAutoArchiveService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
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
    
    func testShouldArchive_PlayedAndOlderThanDays() {
        let thirtyOneDaysAgo = Calendar.current.date(byAdding: .day, value: -31, to: Date())!
        let twentyNineDaysAgo = Calendar.current.date(byAdding: .day, value: -29, to: Date())!
        
        let rule = AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: 30
        )
        
        // Played and old enough - should archive
        let oldPlayed = createEpisode(id: "1", isPlayed: true, pubDate: thirtyOneDaysAgo)
        let shouldArchiveOldPlayed = service.shouldArchive(oldPlayed, basedOn: rule)
        XCTAssertTrue(shouldArchiveOldPlayed)
        
        // Played but not old enough - should not archive
        let recentPlayed = createEpisode(id: "2", isPlayed: true, pubDate: twentyNineDaysAgo)
        let shouldArchiveRecentPlayed = service.shouldArchive(recentPlayed, basedOn: rule)
        XCTAssertFalse(shouldArchiveRecentPlayed)
        
        // Old enough but not played - should not archive
        let oldUnplayed = createEpisode(id: "3", isPlayed: false, pubDate: thirtyOneDaysAgo)
        let shouldArchiveOldUnplayed = service.shouldArchive(oldUnplayed, basedOn: rule)
        XCTAssertFalse(shouldArchiveOldUnplayed)
    }
    
    func testShouldArchive_PlayedRegardlessOfAge() {
        let rule = AutoArchiveRule(condition: .playedRegardlessOfAge)
        
        // Played - should archive
        let played = createEpisode(id: "1", isPlayed: true)
        let shouldArchivePlayed = service.shouldArchive(played, basedOn: rule)
        XCTAssertTrue(shouldArchivePlayed)
        
        // Not played - should not archive
        let unplayed = createEpisode(id: "2", isPlayed: false)
        let shouldArchiveUnplayed = service.shouldArchive(unplayed, basedOn: rule)
        XCTAssertFalse(shouldArchiveUnplayed)
    }
    
    func testShouldArchive_OlderThanDays() {
        let hundredDaysAgo = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let eightyDaysAgo = Calendar.current.date(byAdding: .day, value: -80, to: Date())!
        
        let rule = AutoArchiveRule(
            condition: .olderThanDays,
            daysOld: 90
        )
        
        // Old enough - should archive regardless of play status
        let oldEpisode = createEpisode(id: "1", isPlayed: false, pubDate: hundredDaysAgo)
        let shouldArchiveOldEpisode = service.shouldArchive(oldEpisode, basedOn: rule)
        XCTAssertTrue(shouldArchiveOldEpisode)
        
        // Not old enough - should not archive
        let recentEpisode = createEpisode(id: "2", isPlayed: true, pubDate: eightyDaysAgo)
        let shouldArchiveRecentEpisode = service.shouldArchive(recentEpisode, basedOn: rule)
        XCTAssertFalse(shouldArchiveRecentEpisode)
    }
    
    func testShouldArchive_DownloadedAndPlayed() {
        let rule = AutoArchiveRule(condition: .downloadedAndPlayed)
        
        // Downloaded and played - should archive
        let downloadedPlayed = createEpisode(
            id: "1",
            isPlayed: true,
            downloadStatus: .downloaded
        )
        let shouldArchiveDownloadedPlayed = service.shouldArchive(downloadedPlayed, basedOn: rule)
        XCTAssertTrue(shouldArchiveDownloadedPlayed)
        
        // Downloaded but not played - should not archive
        let downloadedUnplayed = createEpisode(
            id: "2",
            isPlayed: false,
            downloadStatus: .downloaded
        )
        let shouldArchiveDownloadedUnplayed = service.shouldArchive(downloadedUnplayed, basedOn: rule)
        XCTAssertFalse(shouldArchiveDownloadedUnplayed)
        
        // Played but not downloaded - should not archive
        let notDownloadedPlayed = createEpisode(
            id: "3",
            isPlayed: true,
            downloadStatus: .notDownloaded
        )
        let shouldArchiveNotDownloadedPlayed = service.shouldArchive(notDownloadedPlayed, basedOn: rule)
        XCTAssertFalse(shouldArchiveNotDownloadedPlayed)
    }
    
    func testShouldArchive_ExcludeFavorites() {
        let rule = AutoArchiveRule(
            condition: .playedRegardlessOfAge,
            excludeFavorites: true
        )
        
        // Played but favorited - should not archive
        let favoritedPlayed = createEpisode(id: "1", isPlayed: true, isFavorited: true)
        let shouldArchiveFavoritedPlayed = service.shouldArchive(favoritedPlayed, basedOn: rule)
        XCTAssertFalse(shouldArchiveFavoritedPlayed)
        
        // Played and not favorited - should archive
        let regularPlayed = createEpisode(id: "2", isPlayed: true, isFavorited: false)
        let shouldArchiveRegularPlayed = service.shouldArchive(regularPlayed, basedOn: rule)
        XCTAssertTrue(shouldArchiveRegularPlayed)
    }
    
    func testShouldArchive_ExcludeBookmarked() {
        let rule = AutoArchiveRule(
            condition: .playedRegardlessOfAge,
            excludeBookmarked: true
        )
        
        // Played but bookmarked - should not archive
        let bookmarkedPlayed = createEpisode(id: "1", isPlayed: true, isBookmarked: true)
        let shouldArchiveBookmarkedPlayed = service.shouldArchive(bookmarkedPlayed, basedOn: rule)
        XCTAssertFalse(shouldArchiveBookmarkedPlayed)
        
        // Played and not bookmarked - should archive
        let regularPlayed = createEpisode(id: "2", isPlayed: true, isBookmarked: false)
        let shouldArchiveRegularPlayedWhenNotBookmarked = service.shouldArchive(regularPlayed, basedOn: rule)
        XCTAssertTrue(shouldArchiveRegularPlayedWhenNotBookmarked)
    }
    
    func testShouldArchive_AlreadyArchived() {
        let rule = AutoArchiveRule(condition: .playedRegardlessOfAge)
        
        // Already archived - should not archive again
        let alreadyArchived = createEpisode(id: "1", isPlayed: true, isArchived: true)
        let shouldArchiveAlreadyArchived = service.shouldArchive(alreadyArchived, basedOn: rule)
        XCTAssertFalse(shouldArchiveAlreadyArchived)
    }
    
    func testShouldArchive_DisabledRule() {
        let rule = AutoArchiveRule(
            isEnabled: false,
            condition: .playedRegardlessOfAge
        )
        
        // Rule is disabled - should not archive
        let played = createEpisode(id: "1", isPlayed: true)
        let shouldArchivePlayedWhenDisabled = service.shouldArchive(played, basedOn: rule)
        XCTAssertFalse(shouldArchivePlayedWhenDisabled)
    }
    
    func testShouldArchive_InvalidRule() {
        let rule = AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: nil // Invalid - missing required parameter
        )
        
        // Rule is invalid - should not archive
        let episode = createEpisode(id: "1", isPlayed: true)
        let shouldArchiveInvalidRule = service.shouldArchive(episode, basedOn: rule)
        XCTAssertFalse(shouldArchiveInvalidRule)
    }
    
    // MARK: - evaluateRules Tests
    
    func testEvaluateRules_MultipleRules() {
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
    
    func testEvaluateRules_EmptyRules() {
        let episodes = [
            createEpisode(id: "1", isPlayed: true)
        ]
        
        let episodesToArchive = service.evaluateRules([], forEpisodes: episodes)
        
        XCTAssertTrue(episodesToArchive.isEmpty)
    }
    
    func testEvaluateRules_EmptyEpisodes() {
        let rule = AutoArchiveRule(condition: .playedRegardlessOfAge)
        
        let episodesToArchive = service.evaluateRules([rule], forEpisodes: [])
        
        XCTAssertTrue(episodesToArchive.isEmpty)
    }
    
    // MARK: - evaluateForPodcast Tests
    
    func testEvaluateForPodcast_Enabled() {
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
    
    func testEvaluateForPodcast_Disabled() {
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
    
    func testShouldRunAutoArchive_NeverRunBefore() {
        let config = GlobalAutoArchiveConfig(
            isGlobalEnabled: true,
            lastRunAt: nil
        )
        
        let shouldRunEnabled = service.shouldRunAutoArchive(config)
        XCTAssertTrue(shouldRunEnabled)
    }
    
    func testShouldRunAutoArchive_IntervalElapsed() {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let config = GlobalAutoArchiveConfig(
            isGlobalEnabled: true,
            autoRunInterval: 1800, // 30 minutes
            lastRunAt: oneHourAgo
        )
        
        let shouldRunEnabledWithCutoff = service.shouldRunAutoArchive(config)
        XCTAssertTrue(shouldRunEnabledWithCutoff)
    }
    
    func testShouldRunAutoArchive_IntervalNotElapsed() {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let config = GlobalAutoArchiveConfig(
            isGlobalEnabled: true,
            autoRunInterval: 1800, // 30 minutes
            lastRunAt: fiveMinutesAgo
        )
        
        let shouldRunDisabled = service.shouldRunAutoArchive(config)
        XCTAssertFalse(shouldRunDisabled)
    }
    
    func testShouldRunAutoArchive_GloballyDisabled() {
        let config = GlobalAutoArchiveConfig(
            isGlobalEnabled: false,
            lastRunAt: nil
        )
        
        let shouldRunManual = service.shouldRunAutoArchive(config)
        XCTAssertFalse(shouldRunManual)
    }
}

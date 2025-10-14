import XCTest
@testable import CoreModels

final class AutoArchiveRulesTests: XCTestCase {
    
    // MARK: - AutoArchiveCondition Tests
    
    func testAutoArchiveConditionDisplayNames() {
        XCTAssertEqual(AutoArchiveCondition.playedAndOlderThanDays.displayName, "Played and Older Than")
        XCTAssertEqual(AutoArchiveCondition.playedRegardlessOfAge.displayName, "All Played Episodes")
        XCTAssertEqual(AutoArchiveCondition.olderThanDays.displayName, "Older Than")
        XCTAssertEqual(AutoArchiveCondition.downloadedAndPlayed.displayName, "Downloaded and Played")
    }
    
    func testAutoArchiveConditionRequiresDaysParameter() {
        XCTAssertTrue(AutoArchiveCondition.playedAndOlderThanDays.requiresDaysParameter)
        XCTAssertFalse(AutoArchiveCondition.playedRegardlessOfAge.requiresDaysParameter)
        XCTAssertTrue(AutoArchiveCondition.olderThanDays.requiresDaysParameter)
        XCTAssertFalse(AutoArchiveCondition.downloadedAndPlayed.requiresDaysParameter)
    }
    
    // MARK: - AutoArchiveRule Tests
    
    func testAutoArchiveRuleInitialization() {
        let rule = AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: 30
        )
        
        XCTAssertTrue(rule.isEnabled)
        XCTAssertEqual(rule.condition, .playedAndOlderThanDays)
        XCTAssertEqual(rule.daysOld, 30)
        XCTAssertTrue(rule.excludeFavorites)
        XCTAssertTrue(rule.excludeBookmarked)
        XCTAssertNil(rule.lastAppliedAt)
    }
    
    func testAutoArchiveRuleValidation() {
        // Valid rule with required days parameter
        let validRule = AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: 30
        )
        XCTAssertTrue(validRule.isValid)
        
        // Invalid rule missing days parameter
        let invalidRule = AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: nil
        )
        XCTAssertFalse(invalidRule.isValid)
        
        // Valid rule with zero days (invalid)
        let zeroRule = AutoArchiveRule(
            condition: .olderThanDays,
            daysOld: 0
        )
        XCTAssertFalse(zeroRule.isValid)
        
        // Valid rule not requiring days parameter
        let noParamRule = AutoArchiveRule(
            condition: .playedRegardlessOfAge
        )
        XCTAssertTrue(noParamRule.isValid)
    }
    
    func testAutoArchiveRuleDescription() {
        let rule1 = AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: 30,
            excludeFavorites: true,
            excludeBookmarked: true
        )
        XCTAssertTrue(rule1.description.contains("Archive played episodes older than 30 days"))
        XCTAssertTrue(rule1.description.contains("(except favorites)"))
        XCTAssertTrue(rule1.description.contains("(except bookmarked)"))
        
        let rule2 = AutoArchiveRule(
            condition: .playedRegardlessOfAge,
            excludeFavorites: false,
            excludeBookmarked: false
        )
        XCTAssertTrue(rule2.description.contains("Archive all played episodes"))
        XCTAssertFalse(rule2.description.contains("except"))
    }
    
    func testAutoArchiveRuleWithLastApplied() {
        let rule = AutoArchiveRule(condition: .playedRegardlessOfAge)
        let appliedDate = Date()
        let updatedRule = rule.withLastApplied(appliedDate)
        
        XCTAssertEqual(updatedRule.lastAppliedAt, appliedDate)
        XCTAssertEqual(updatedRule.id, rule.id)
        XCTAssertEqual(updatedRule.condition, rule.condition)
    }
    
    func testAutoArchiveRuleWithEnabled() {
        let rule = AutoArchiveRule(isEnabled: true, condition: .playedRegardlessOfAge)
        let disabledRule = rule.withEnabled(false)
        
        XCTAssertFalse(disabledRule.isEnabled)
        XCTAssertEqual(disabledRule.id, rule.id)
    }
    
    // MARK: - Predefined Rules Tests
    
    func testPredefinedRules() {
        let playedOld = AutoArchiveRule.playedOlderThan30Days
        XCTAssertEqual(playedOld.condition, .playedAndOlderThanDays)
        XCTAssertEqual(playedOld.daysOld, 30)
        XCTAssertTrue(playedOld.isValid)
        
        let allPlayed = AutoArchiveRule.allPlayedImmediately
        XCTAssertEqual(allPlayed.condition, .playedRegardlessOfAge)
        XCTAssertTrue(allPlayed.isValid)
        
        let oldEpisodes = AutoArchiveRule.olderThan90Days
        XCTAssertEqual(oldEpisodes.condition, .olderThanDays)
        XCTAssertEqual(oldEpisodes.daysOld, 90)
        XCTAssertTrue(oldEpisodes.isValid)
        
        let downloaded = AutoArchiveRule.downloadedAndPlayed
        XCTAssertEqual(downloaded.condition, .downloadedAndPlayed)
        XCTAssertTrue(downloaded.isValid)
    }
    
    // MARK: - PodcastAutoArchiveConfig Tests
    
    func testPodcastAutoArchiveConfigInitialization() {
        let config = PodcastAutoArchiveConfig(podcastId: "podcast-1")
        
        XCTAssertEqual(config.podcastId, "podcast-1")
        XCTAssertTrue(config.rules.isEmpty)
        XCTAssertFalse(config.isEnabled)
    }
    
    func testPodcastAutoArchiveConfigWithRules() {
        let rule = AutoArchiveRule.playedOlderThan30Days
        let config = PodcastAutoArchiveConfig(podcastId: "podcast-1")
        let updatedConfig = config.withRules([rule])
        
        XCTAssertEqual(updatedConfig.rules.count, 1)
        XCTAssertEqual(updatedConfig.rules[0].id, rule.id)
        XCTAssertEqual(updatedConfig.podcastId, "podcast-1")
    }
    
    func testPodcastAutoArchiveConfigWithEnabled() {
        let config = PodcastAutoArchiveConfig(podcastId: "podcast-1", isEnabled: false)
        let enabledConfig = config.withEnabled(true)
        
        XCTAssertTrue(enabledConfig.isEnabled)
        XCTAssertEqual(enabledConfig.podcastId, "podcast-1")
    }
    
    // MARK: - GlobalAutoArchiveConfig Tests
    
    func testGlobalAutoArchiveConfigInitialization() {
        let config = GlobalAutoArchiveConfig()
        
        XCTAssertTrue(config.globalRules.isEmpty)
        XCTAssertTrue(config.perPodcastConfigs.isEmpty)
        XCTAssertFalse(config.isGlobalEnabled)
        XCTAssertEqual(config.autoRunInterval, 86400) // 1 day
        XCTAssertNil(config.lastRunAt)
    }
    
    func testGlobalAutoArchiveConfigForPodcast() {
        let rule = AutoArchiveRule.playedOlderThan30Days
        let podcastConfig = PodcastAutoArchiveConfig(
            podcastId: "podcast-1",
            rules: [rule],
            isEnabled: true
        )
        
        let globalConfig = GlobalAutoArchiveConfig(
            perPodcastConfigs: ["podcast-1": podcastConfig]
        )
        
        let retrievedConfig = globalConfig.configForPodcast("podcast-1")
        XCTAssertEqual(retrievedConfig.podcastId, "podcast-1")
        XCTAssertTrue(retrievedConfig.isEnabled)
        XCTAssertEqual(retrievedConfig.rules.count, 1)
        
        // Test fallback for non-existent podcast
        let defaultConfig = globalConfig.configForPodcast("podcast-2")
        XCTAssertEqual(defaultConfig.podcastId, "podcast-2")
        XCTAssertFalse(defaultConfig.isEnabled)
        XCTAssertTrue(defaultConfig.rules.isEmpty)
    }
    
    func testGlobalAutoArchiveConfigWithPodcastConfig() {
        let config = GlobalAutoArchiveConfig()
        let podcastConfig = PodcastAutoArchiveConfig(
            podcastId: "podcast-1",
            isEnabled: true
        )
        
        let updatedConfig = config.withPodcastConfig(podcastConfig)
        
        XCTAssertEqual(updatedConfig.perPodcastConfigs.count, 1)
        XCTAssertNotNil(updatedConfig.perPodcastConfigs["podcast-1"])
    }
    
    func testGlobalAutoArchiveConfigWithGlobalRules() {
        let rule = AutoArchiveRule.playedOlderThan30Days
        let config = GlobalAutoArchiveConfig()
        let updatedConfig = config.withGlobalRules([rule])
        
        XCTAssertEqual(updatedConfig.globalRules.count, 1)
        XCTAssertEqual(updatedConfig.globalRules[0].id, rule.id)
    }
    
    func testGlobalAutoArchiveConfigWithLastRun() {
        let config = GlobalAutoArchiveConfig()
        let runDate = Date()
        let updatedConfig = config.withLastRun(runDate)
        
        XCTAssertEqual(updatedConfig.lastRunAt, runDate)
    }
    
    func testGlobalAutoArchiveConfigWithGlobalEnabled() {
        let config = GlobalAutoArchiveConfig(isGlobalEnabled: false)
        let enabledConfig = config.withGlobalEnabled(true)
        
        XCTAssertTrue(enabledConfig.isGlobalEnabled)
    }
    
    // MARK: - Codable Tests
    
    func testAutoArchiveRuleCodable() throws {
        let rule = AutoArchiveRule(
            condition: .playedAndOlderThanDays,
            daysOld: 30,
            excludeFavorites: true,
            excludeBookmarked: false
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(rule)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AutoArchiveRule.self, from: data)
        
        XCTAssertEqual(decoded.id, rule.id)
        XCTAssertEqual(decoded.condition, rule.condition)
        XCTAssertEqual(decoded.daysOld, rule.daysOld)
        XCTAssertEqual(decoded.excludeFavorites, rule.excludeFavorites)
        XCTAssertEqual(decoded.excludeBookmarked, rule.excludeBookmarked)
    }
    
    func testPodcastAutoArchiveConfigCodable() throws {
        let rule = AutoArchiveRule.allPlayedImmediately
        let config = PodcastAutoArchiveConfig(
            podcastId: "podcast-1",
            rules: [rule],
            isEnabled: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PodcastAutoArchiveConfig.self, from: data)
        
        XCTAssertEqual(decoded.podcastId, config.podcastId)
        XCTAssertEqual(decoded.rules.count, config.rules.count)
        XCTAssertEqual(decoded.isEnabled, config.isEnabled)
    }
    
    func testGlobalAutoArchiveConfigCodable() throws {
        let globalRule = AutoArchiveRule.playedOlderThan30Days
        let podcastConfig = PodcastAutoArchiveConfig(
            podcastId: "podcast-1",
            isEnabled: true
        )
        
        let config = GlobalAutoArchiveConfig(
            globalRules: [globalRule],
            perPodcastConfigs: ["podcast-1": podcastConfig],
            isGlobalEnabled: true,
            autoRunInterval: 3600
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GlobalAutoArchiveConfig.self, from: data)
        
        XCTAssertEqual(decoded.globalRules.count, config.globalRules.count)
        XCTAssertEqual(decoded.perPodcastConfigs.count, config.perPodcastConfigs.count)
        XCTAssertEqual(decoded.isGlobalEnabled, config.isGlobalEnabled)
        XCTAssertEqual(decoded.autoRunInterval, config.autoRunInterval)
    }
}

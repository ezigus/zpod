import XCTest
@testable import Persistence
import CoreModels

final class AutoArchiveRepositoryTests: XCTestCase {
    
    var repository: UserDefaultsAutoArchiveRepository!
    var testUserDefaults: UserDefaults!
    
    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create a new user defaults suite for testing
        let suiteName = "test.autoarchive.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        repository = UserDefaultsAutoArchiveRepository(userDefaults: userDefaults)
        testUserDefaults = userDefaults
    }

    override func tearDownWithError() throws {
        // Clean up test data
        if let suite = testUserDefaults.dictionaryRepresentation().keys.first {
            testUserDefaults.removePersistentDomain(forName: suite)
        }
        testUserDefaults = nil
        repository = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Global Config Tests
    
    func testSaveAndLoadGlobalConfig() async throws {
        let rule = AutoArchiveRule.playedOlderThan30Days
        let config = GlobalAutoArchiveConfig(
            globalRules: [rule],
            isGlobalEnabled: true,
            autoRunInterval: 3600
        )
        
        // Save config
        try await repository.saveGlobalConfig(config)
        
        // Load config
        let loaded = try await repository.loadGlobalConfig()
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.globalRules.count, 1)
        XCTAssertEqual(loaded?.isGlobalEnabled, true)
        XCTAssertEqual(loaded?.autoRunInterval, 3600)
    }
    
    func testLoadGlobalConfig_NotFound() async throws {
        let loaded = try await repository.loadGlobalConfig()
        XCTAssertNil(loaded)
    }
    
    func testUpdateGlobalConfig() async throws {
        let initialConfig = GlobalAutoArchiveConfig(isGlobalEnabled: false)
        try await repository.saveGlobalConfig(initialConfig)
        
        let updatedConfig = initialConfig.withGlobalEnabled(true)
        try await repository.saveGlobalConfig(updatedConfig)
        
        let loaded = try await repository.loadGlobalConfig()
        
        XCTAssertNotNil(loaded)
        XCTAssertTrue(loaded?.isGlobalEnabled ?? false)
    }
    
    // MARK: - Podcast Config Tests
    
    func testSaveAndLoadPodcastConfig() async throws {
        let rule = AutoArchiveRule(condition: .playedRegardlessOfAge)
        let config = PodcastAutoArchiveConfig(
            podcastId: "podcast-1",
            rules: [rule],
            isEnabled: true
        )
        
        // Save config
        try await repository.savePodcastConfig(config)
        
        // Load config
        let loaded = try await repository.loadPodcastConfig(podcastId: "podcast-1")
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.podcastId, "podcast-1")
        XCTAssertEqual(loaded?.rules.count, 1)
        XCTAssertTrue(loaded?.isEnabled ?? false)
    }
    
    func testLoadPodcastConfig_NotFound() async throws {
        let loaded = try await repository.loadPodcastConfig(podcastId: "nonexistent")
        XCTAssertNil(loaded)
    }
    
    func testSaveMultiplePodcastConfigs() async throws {
        let config1 = PodcastAutoArchiveConfig(podcastId: "podcast-1", isEnabled: true)
        let config2 = PodcastAutoArchiveConfig(podcastId: "podcast-2", isEnabled: false)
        
        try await repository.savePodcastConfig(config1)
        try await repository.savePodcastConfig(config2)
        
        let loaded1 = try await repository.loadPodcastConfig(podcastId: "podcast-1")
        let loaded2 = try await repository.loadPodcastConfig(podcastId: "podcast-2")
        
        XCTAssertNotNil(loaded1)
        XCTAssertNotNil(loaded2)
        XCTAssertTrue(loaded1?.isEnabled ?? false)
        XCTAssertFalse(loaded2?.isEnabled ?? true)
    }
    
    func testUpdatePodcastConfig() async throws {
        let initialConfig = PodcastAutoArchiveConfig(
            podcastId: "podcast-1",
            isEnabled: false
        )
        try await repository.savePodcastConfig(initialConfig)
        
        let updatedConfig = initialConfig.withEnabled(true)
        try await repository.savePodcastConfig(updatedConfig)
        
        let loaded = try await repository.loadPodcastConfig(podcastId: "podcast-1")
        
        XCTAssertNotNil(loaded)
        XCTAssertTrue(loaded?.isEnabled ?? false)
    }
    
    func testDeletePodcastConfig() async throws {
        let config = PodcastAutoArchiveConfig(podcastId: "podcast-1", isEnabled: true)
        try await repository.savePodcastConfig(config)
        
        // Verify it exists
        var loaded = try await repository.loadPodcastConfig(podcastId: "podcast-1")
        XCTAssertNotNil(loaded)
        
        // Delete it
        try await repository.deletePodcastConfig(podcastId: "podcast-1")
        
        // Verify it's gone
        loaded = try await repository.loadPodcastConfig(podcastId: "podcast-1")
        XCTAssertNil(loaded)
    }
    
    func testDeleteNonexistentPodcastConfig() async throws {
        // Should not throw
        try await repository.deletePodcastConfig(podcastId: "nonexistent")
    }
    
    // MARK: - Complex Scenarios
    
    func testSaveComplexGlobalConfig() async throws {
        let globalRule1 = AutoArchiveRule.playedOlderThan30Days
        let globalRule2 = AutoArchiveRule.olderThan90Days
        
        let podcastConfig1 = PodcastAutoArchiveConfig(
            podcastId: "podcast-1",
            rules: [AutoArchiveRule.allPlayedImmediately],
            isEnabled: true
        )
        
        let config = GlobalAutoArchiveConfig(
            globalRules: [globalRule1, globalRule2],
            perPodcastConfigs: ["podcast-1": podcastConfig1],
            isGlobalEnabled: true,
            autoRunInterval: 7200,
            lastRunAt: Date()
        )
        
        try await repository.saveGlobalConfig(config)
        let loaded = try await repository.loadGlobalConfig()
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.globalRules.count, 2)
        XCTAssertEqual(loaded?.perPodcastConfigs.count, 1)
        XCTAssertNotNil(loaded?.perPodcastConfigs["podcast-1"])
        XCTAssertNotNil(loaded?.lastRunAt)
    }
    
    func testRoundTripWithAllRuleTypes() async throws {
        let rules = [
            AutoArchiveRule.playedOlderThan30Days,
            AutoArchiveRule.allPlayedImmediately,
            AutoArchiveRule.olderThan90Days,
            AutoArchiveRule.downloadedAndPlayed
        ]
        
        let config = PodcastAutoArchiveConfig(
            podcastId: "podcast-1",
            rules: rules,
            isEnabled: true
        )
        
        try await repository.savePodcastConfig(config)
        let loaded = try await repository.loadPodcastConfig(podcastId: "podcast-1")
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.rules.count, 4)
        
        // Verify each rule type is preserved
        let loadedConditions = loaded?.rules.map { $0.condition } ?? []
        XCTAssertTrue(loadedConditions.contains(.playedAndOlderThanDays))
        XCTAssertTrue(loadedConditions.contains(.playedRegardlessOfAge))
        XCTAssertTrue(loadedConditions.contains(.olderThanDays))
        XCTAssertTrue(loadedConditions.contains(.downloadedAndPlayed))
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentSaveAndLoad() async throws {
        let config = GlobalAutoArchiveConfig(isGlobalEnabled: true)
        
        // Perform concurrent operations
        guard let repository = repository else {
            XCTFail("Repository not initialized")
            return
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            // Save multiple times concurrently
            for _ in 0..<5 {
                group.addTask { [repository] in
                    try await repository.saveGlobalConfig(config)
                }
            }
            
            // Load multiple times concurrently
            for _ in 0..<5 {
                group.addTask { [repository] in
                    _ = try await repository.loadGlobalConfig()
                }
            }
            
            try await group.waitForAll()
        }

        // Should still be able to load successfully
        let loaded = try await repository.loadGlobalConfig()
        XCTAssertNotNil(loaded)
    }
}

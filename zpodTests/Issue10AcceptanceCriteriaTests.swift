import XCTest
@preconcurrency import Combine
@testable import zpod

@MainActor
final class Issue10AcceptanceCriteriaTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    private var userDefaults: UserDefaults!
    private var suiteName: String!
    private var repository: SettingsRepository!
    private var settingsManager: SettingsManager!
    private var updateService: UpdateFrequencyService!
    
    override func setUp() async throws {
        // Remove super.setUp() call to avoid Sendable violations in Swift 6
        cancellables = Set<AnyCancellable>()
        
        // Use test-specific UserDefaults to avoid pollution
        suiteName = "test-acceptance-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        
        // Create repository and services properly for async testing
        repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        settingsManager = SettingsManager(repository: repository)
        updateService = UpdateFrequencyService(settingsManager: settingsManager)
    }
    
    override func tearDown() async throws {
        cancellables = nil
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        repository = nil
        settingsManager = nil
        updateService = nil
        // Remove super.tearDown() call to avoid Sendable violations in Swift 6
    }
    
    // MARK: - Acceptance Criteria Tests
    
    func testAcceptanceCriteria_PodcastWithCustomInterval_UsesItsInterval() async {
        // Given: podcast with custom interval
        let podcastId = "test-podcast-custom"
        
        // Set global default to every 6 hours
        let globalSettings = DownloadSettings(
            autoDownloadEnabled: false,
            wifiOnly: true,
            maxConcurrentDownloads: 3,
            retentionPolicy: .keepLatest(5),
            defaultUpdateFrequency: .every6Hours
        )
        settingsManager.updateGlobalDownloadSettings(globalSettings)
        
        // Set podcast-specific override to hourly
        let podcastSettings = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: nil,
            wifiOnly: nil,
            retentionPolicy: nil,
            updateFrequency: .hourly
        )
        settingsManager.updatePodcastDownloadSettings(podcastId: podcastId, podcastSettings)
        
        // When: next refresh uses its interval
        let effectiveFrequency = settingsManager.effectiveUpdateFrequency(for: podcastId)
        let nextRefreshTime = updateService.computeNextRefreshTime(for: podcastId)
        
        // Then: Should use podcast's custom interval (hourly), not global (every6Hours)
        XCTAssertEqual(effectiveFrequency, .hourly, "Should use podcast's custom interval")
        XCTAssertNotNil(nextRefreshTime, "Should have next refresh time")
        
        // Verify the timing is approximately 1 hour (3600 seconds), not 6 hours (21600 seconds)
        let timeInterval = nextRefreshTime!.timeIntervalSinceNow
        XCTAssertTrue(timeInterval >= 3590 && timeInterval <= 3610, "Should be ~1 hour from now, got \(timeInterval) seconds")
    }
    
    func testAcceptanceCriteria_RemovingCustomInterval_RevertsToGlobalDefault() async {
        // Given: podcast with custom interval that will be removed
        let podcastId = "test-podcast-revert"
        
        // Set global default to daily
        let globalSettings = DownloadSettings(
            autoDownloadEnabled: false,
            wifiOnly: true,
            maxConcurrentDownloads: 3,
            retentionPolicy: .keepLatest(5),
            defaultUpdateFrequency: .daily
        )
        settingsManager.updateGlobalDownloadSettings(globalSettings)
        
        // Set podcast-specific override to every 3 hours
        let podcastSettings = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: nil,
            wifiOnly: nil,
            retentionPolicy: nil,
            updateFrequency: .every3Hours
        )
        settingsManager.updatePodcastDownloadSettings(podcastId: podcastId, podcastSettings)
        
        // Verify custom interval is active
        let beforeRemoval = settingsManager.effectiveUpdateFrequency(for: podcastId)
        XCTAssertEqual(beforeRemoval, .every3Hours)
        
        // When: removing custom interval
        settingsManager.updatePodcastDownloadSettings(podcastId: podcastId, nil)
        
        // Then: reverts to global default
        let effectiveFrequency = settingsManager.effectiveUpdateFrequency(for: podcastId)
        let nextRefreshTime = updateService.computeNextRefreshTime(for: podcastId)
        
        XCTAssertEqual(effectiveFrequency, .daily, "Should revert to global default (daily)")
        XCTAssertNotNil(nextRefreshTime, "Should have next refresh time")
        
        // Verify the timing is approximately 1 day (86400 seconds), not 3 hours (10800 seconds)
        let timeInterval = nextRefreshTime!.timeIntervalSinceNow
        XCTAssertTrue(timeInterval >= 86390 && timeInterval <= 86410, "Should be ~1 day from now, got \(timeInterval) seconds")
    }
    
    func testAcceptanceCriteria_PodcastWithoutCustomInterval_UsesGlobalDefault() async {
        // Given: podcast without any custom interval (only global settings)
        let podcastId = "test-podcast-global"
        
        // Set global default to every 12 hours
        let globalSettings = DownloadSettings(
            autoDownloadEnabled: false,
            wifiOnly: true,
            maxConcurrentDownloads: 3,
            retentionPolicy: .keepLatest(5),
            defaultUpdateFrequency: .every12Hours
        )
        settingsManager.updateGlobalDownloadSettings(globalSettings)
        
        // When: getting effective update frequency (no podcast overrides set)
        let effectiveFrequency = settingsManager.effectiveUpdateFrequency(for: podcastId)
        let nextRefreshTime = updateService.computeNextRefreshTime(for: podcastId)
        
        // Then: should use global default
        XCTAssertEqual(effectiveFrequency, .every12Hours, "Should use global default")
        XCTAssertNotNil(nextRefreshTime, "Should have next refresh time")
        
        // Verify the timing is approximately 12 hours (43200 seconds)
        let timeInterval = nextRefreshTime!.timeIntervalSinceNow
        XCTAssertTrue(timeInterval >= 43190 && timeInterval <= 43210, "Should be ~12 hours from now, got \(timeInterval) seconds")
    }
    
    func testAcceptanceCriteria_ManualFrequency_NoAutomaticRefresh() async {
        // Given: podcast with manual frequency setting
        let podcastId = "test-podcast-manual"
        
        // Set podcast to manual refresh
        let podcastSettings = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: nil,
            wifiOnly: nil,
            retentionPolicy: nil,
            updateFrequency: .manual
        )
        settingsManager.updatePodcastDownloadSettings(podcastId: podcastId, podcastSettings)
        
        // When: computing next refresh time
        let effectiveFrequency = settingsManager.effectiveUpdateFrequency(for: podcastId)
        let nextRefreshTime = updateService.computeNextRefreshTime(for: podcastId)
        
        // Then: should have manual frequency and no automatic refresh
        XCTAssertEqual(effectiveFrequency, .manual, "Should use manual frequency")
        XCTAssertNil(nextRefreshTime, "Should not have automatic refresh time")
    }
    
    func testAcceptanceCriteria_ScheduleTracking_UpdatesAfterRefresh() async {
        // Given: podcast with custom frequency
        let podcastId = "test-podcast-tracking"
        
        let globalSettings = DownloadSettings(
            autoDownloadEnabled: false,
            wifiOnly: true,
            maxConcurrentDownloads: 3,
            retentionPolicy: .keepLatest(5),
            defaultUpdateFrequency: .every3Hours
        )
        settingsManager.updateGlobalDownloadSettings(globalSettings)
        
        // Initialize schedule
        updateService.initializeSchedule(for: podcastId)
        let initialSchedule = updateService.getSchedule(for: podcastId)!
        
        // When: marking podcast as refreshed
        updateService.markPodcastRefreshed(podcastId)
        
        // Then: schedule should be updated
        let updatedSchedule = updateService.getSchedule(for: podcastId)!
        
        XCTAssertEqual(updatedSchedule.podcastId, podcastId)
        XCTAssertTrue(updatedSchedule.lastCheckedDate > initialSchedule.lastCheckedDate, "Last checked should be updated")
        XCTAssertTrue(updatedSchedule.nextDueDate > initialSchedule.nextDueDate, "Next due should be pushed forward")
        
        // Verify new next due time is ~3 hours from now
        let timeInterval = updatedSchedule.nextDueDate.timeIntervalSinceNow
        XCTAssertTrue(timeInterval >= 10790 && timeInterval <= 10810, "Should be ~3 hours from now, got \(timeInterval) seconds")
    }
}

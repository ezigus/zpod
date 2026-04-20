//
//  PodcastCustomSettingsViewModelTests.swift
//  LibraryFeatureTests
//
//  Unit tests for PodcastCustomSettingsViewModel (Issue #478: [06.5.1], #468: [06.2.1]).
//
//  Spec coverage (Given/When/Then):
//    AC-Reset-1 — Happy path: Reset confirmed removes download + playback overrides
//    AC-Reset-2 — Re-entrant: A second reset call while one is in-flight is a no-op
//    AC-Reset-3 — No-op safety: Reset on a podcast with no overrides does not crash
//    AC-Reset-4 — isResetting is false after reset completes
//    AC-Priority-1 — loadPriority reads the stored priority value
//    AC-Priority-2 — savePriority persists the current priority to storage
//    AC-Priority-3 — resetSettings sets priority back to 0
//

import XCTest
@testable import LibraryFeature
import CoreModels
import Persistence
import SettingsDomain

@MainActor
final class PodcastCustomSettingsViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeSUT(podcastId: String = "test-podcast-478") -> (
        vm: PodcastCustomSettingsViewModel,
        manager: SettingsManager,
        repository: UserDefaultsSettingsRepository
    ) {
        let suiteName = "PodcastCustomSettings-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let manager = SettingsManager(repository: repository)
        let podcast = Podcast(
            id: podcastId,
            title: "Test Podcast",
            author: "Author",
            description: "Description",
            artworkURL: nil,
            feedURL: URL(string: "https://example.com/feed.rss")!,
            categories: [],
            episodes: [],
            isSubscribed: true
        )
        let vm = PodcastCustomSettingsViewModel(podcast: podcast, settingsManager: manager)
        return (vm, manager, repository)
    }

    // MARK: - AC-Reset-1: Happy path

    func testResetRemovesDownloadAndPlaybackOverrides() async {
        // Given: a podcast with both download and playback overrides
        let podcastId = "reset-happy-path-478"
        let (vm, manager, repository) = makeSUT(podcastId: podcastId)

        let downloadOverride = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: true,
            wifiOnly: false,
            retentionPolicy: .keepLatest(10)
        )
        let playbackOverride = PodcastPlaybackSettings(
            speed: 1.5,
            introSkipDuration: 30,
            outroSkipDuration: 60,
            skipForwardInterval: nil,
            skipBackwardInterval: nil
        )
        await manager.updatePodcastDownloadSettings(podcastId: podcastId, downloadOverride)
        await manager.updatePodcastPlaybackSettings(podcastId: podcastId, playbackOverride)

        let beforeDownload = await repository.loadPodcastDownloadSettings(podcastId: podcastId)
        let beforePlayback = await repository.loadPodcastPlaybackSettings(podcastId: podcastId)
        XCTAssertNotNil(beforeDownload, "Precondition: download override should exist")
        XCTAssertNotNil(beforePlayback, "Precondition: playback override should exist")

        // When: reset is confirmed
        await vm.resetSettings()?.value

        // Then: both overrides are removed from the repository
        let afterDownload = await repository.loadPodcastDownloadSettings(podcastId: podcastId)
        let afterPlayback = await repository.loadPodcastPlaybackSettings(podcastId: podcastId)
        XCTAssertNil(afterDownload, "Download override should be nil after reset")
        XCTAssertNil(afterPlayback, "Playback override should be nil after reset")
    }

    // MARK: - AC-Reset-2: Re-entrant guard

    func testSecondResetCallWhileInFlightIsIgnored() async {
        // Given: a view model
        let (vm, _, _) = makeSUT()

        // When: resetSettings is called twice rapidly
        let task1 = vm.resetSettings()
        // isResetting is now true; second call should return nil
        let task2 = vm.resetSettings()

        await task1?.value

        // Then: second call returns nil (no-op) since a reset is already in flight
        XCTAssertNil(task2, "Re-entrant reset should return nil while a reset is in flight")
    }

    // MARK: - AC-Reset-3: No-op safety

    func testResetOnPodcastWithNoOverridesDoesNotCrash() async {
        // Given: a podcast with no existing overrides
        let (vm, _, _) = makeSUT()

        // When/Then: reset does not crash and completes normally
        await vm.resetSettings()?.value
    }

    // MARK: - AC-Reset-4: isResetting state

    func testIsResettingIsFalseAfterCompletion() async {
        // Given: a view model
        let (vm, _, _) = makeSUT()

        // When: reset completes
        await vm.resetSettings()?.value

        // Then: isResetting is false
        XCTAssertFalse(vm.isResetting, "isResetting should be false after reset completes")
    }

    // MARK: - AC-Priority-1: loadPriority reads stored value

    func testLoadPriority_loadsFromStorage() async {
        // Given: a podcast with priority 7 already saved in storage
        let podcastId = "priority-load-test-468"
        let (vm, manager, _) = makeSUT(podcastId: podcastId)

        let settingsWithPriority = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: nil,
            wifiOnly: nil,
            retentionPolicy: nil,
            updateFrequency: nil,
            priority: 7
        )
        await manager.updatePodcastDownloadSettings(podcastId: podcastId, settingsWithPriority)
        XCTAssertEqual(vm.priority, 0, "Precondition: priority starts at 0 before load")

        // When: loadPriority is called
        await vm.loadPriority()

        // Then: priority reflects the stored value
        XCTAssertEqual(vm.priority, 7, "loadPriority should read the stored priority (7)")
    }

    // MARK: - AC-Priority-2: savePriority persists the current priority

    func testSavePriority_persistsValue() async {
        // Given: a view model with priority set to -3
        let podcastId = "priority-save-test-468"
        let (vm, _, repository) = makeSUT(podcastId: podcastId)
        vm.priority = -3

        // When: savePriority is called
        await vm.savePriority()

        // Then: storage reflects the saved priority
        let stored = await repository.loadPodcastDownloadSettings(podcastId: podcastId)
        XCTAssertNotNil(stored, "savePriority should create a download settings entry")
        XCTAssertEqual(stored?.priority, -3, "Stored priority should be -3")
    }

    // MARK: - AC-Priority-3: resetSettings resets priority to 0

    func testResetSettings_setsPriorityToZero() async {
        // Given: a view model with priority set to 5
        let podcastId = "priority-reset-test-468"
        let (vm, manager, _) = makeSUT(podcastId: podcastId)

        let settingsWithPriority = PodcastDownloadSettings(
            podcastId: podcastId,
            autoDownloadEnabled: nil,
            wifiOnly: nil,
            retentionPolicy: nil,
            updateFrequency: nil,
            priority: 5
        )
        await manager.updatePodcastDownloadSettings(podcastId: podcastId, settingsWithPriority)
        await vm.loadPriority()
        XCTAssertEqual(vm.priority, 5, "Precondition: priority should be 5 after load")

        // When: reset is called
        await vm.resetSettings()?.value

        // Then: priority returns to 0
        XCTAssertEqual(vm.priority, 0, "resetSettings should set priority back to 0")
    }
}

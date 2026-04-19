//
//  PodcastCustomSettingsViewModelTests.swift
//  LibraryFeatureTests
//
//  Unit tests for PodcastCustomSettingsViewModel (Issue #478: [06.5.1]).
//
//  Spec coverage (Given/When/Then):
//    AC-Reset-1 — Happy path: Reset confirmed removes download + playback overrides
//    AC-Reset-2 — Re-entrant: A second reset call while one is in-flight is a no-op
//    AC-Reset-3 — No-op safety: Reset on a podcast with no overrides does not crash
//    AC-Reset-4 — isResetting is false after reset completes
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
}

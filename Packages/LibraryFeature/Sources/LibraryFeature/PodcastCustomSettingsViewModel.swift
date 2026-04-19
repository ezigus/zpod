//
//  PodcastCustomSettingsViewModel.swift
//  LibraryFeature
//
//  View model for PodcastCustomSettingsView (Issue #478: [06.5.1]).
//
//  Owns the reset logic so it can be unit-tested independently of the SwiftUI view.
//

import CoreModels
import Foundation
import OSLog
import SettingsDomain

/// View model for per-podcast custom settings.
///
/// Owns the "Reset to Global Defaults" logic: nullifying both the download and
/// playback overrides for the given podcast in `SettingsManager`.
///
/// - Note: Per-podcast filter/sort preferences (stored in `GlobalFilterPreferences
///   .perPodcastPreferences`) will also need to be cleared here once those overrides
///   are implemented in 06.3.4 / 06.5.2. TODO: [#06.5.2] extend reset to clear
///   `perPodcastPreferences[podcastId]` when that field is wired.
@MainActor
final class PodcastCustomSettingsViewModel: ObservableObject {
    @Published private(set) var isResetting: Bool = false

    let podcast: Podcast
    private let settingsManager: SettingsManager
    private(set) var resetTask: Task<Void, Never>?

    private static let logger = Logger(
        subsystem: "us.zig.zpod.library",
        category: "PodcastCustomSettingsViewModel"
    )

    init(podcast: Podcast, settingsManager: SettingsManager) {
        self.podcast = podcast
        self.settingsManager = settingsManager
    }

    /// Resets all per-podcast overrides to global defaults.
    ///
    /// Nils out download and playback overrides so the podcast falls back to
    /// the global `SettingsManager` values. Returns the backing `Task` so
    /// callers (e.g. unit tests) can `await` completion. Returns `nil` if a
    /// reset is already in flight.
    @discardableResult
    func resetSettings() -> Task<Void, Never>? {
        guard !isResetting else { return nil }
        isResetting = true
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performReset()
        }
        resetTask = task
        return task
    }

    // MARK: - Private

    private func performReset() async {
        let podcastId = podcast.id
        Self.logger.debug("Resetting all settings for podcast \(podcastId)")
        await settingsManager.updatePodcastDownloadSettings(podcastId: podcastId, nil)
        await settingsManager.updatePodcastPlaybackSettings(podcastId: podcastId, nil)
        Self.logger.debug("Reset complete for podcast \(podcastId)")
        isResetting = false
    }
}

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
///   are implemented in 06.3.4 / 06.5.2.
// TODO: [Issue #06.5.2] Extend reset to clear `perPodcastPreferences[podcastId]` when that field is wired.
@MainActor
final class PodcastCustomSettingsViewModel: ObservableObject {
    @Published private(set) var isResetting: Bool = false
    /// Download priority offset (-10..+10). Loaded from storage; saved immediately on change.
    @Published var priority: Int = 0

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

    /// Load persisted priority from storage. Call on view appear.
    func loadPriority() async {
        let settings = await settingsManager.loadPodcastDownloadSettings(podcastId: podcast.id)
        priority = settings?.priority ?? 0
    }

    /// Persist the current priority immediately.
    func savePriority() async {
        let existing = await settingsManager.loadPodcastDownloadSettings(podcastId: podcast.id)
        // Preserve all other override fields; only update priority.
        let updated = PodcastDownloadSettings(
            podcastId: podcast.id,
            autoDownloadEnabled: existing?.autoDownloadEnabled,
            wifiOnly: existing?.wifiOnly,
            retentionPolicy: existing?.retentionPolicy,
            updateFrequency: existing?.updateFrequency,
            priority: priority
        )
        await settingsManager.updatePodcastDownloadSettings(podcastId: podcast.id, updated)
        Self.logger.debug("Saved priority \(self.priority) for podcast \(self.podcast.id)")
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
        priority = 0
        Self.logger.debug("Reset complete for podcast \(podcastId)")
        isResetting = false
    }
}

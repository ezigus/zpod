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
@MainActor
final class PodcastCustomSettingsViewModel: ObservableObject {
    // TODO: [Issue #06.5.2] Extend reset to clear `perPodcastPreferences[podcastId]` when that field is wired.
    @Published private(set) var isResetting: Bool = false
    /// Download priority offset (-10..+10). Loaded from storage; saved immediately on change.
    @Published var priority: Int = 0

    let podcast: Podcast
    private let settingsManager: SettingsManager
    private(set) var resetTask: Task<Void, Never>?
    private var pendingSaveTask: Task<Void, Never>?

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

    /// Cancel any pending save and schedule a new one.
    ///
    /// Calling this on rapid slider changes ensures only the final settled value
    /// is written to storage, avoiding a queue of racing save tasks.
    func scheduleSave() {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { await savePriority() }
    }

    /// Wait for any in-flight save to complete before proceeding.
    ///
    /// Call this before dismissing the sheet so that the parent's `onDismiss`
    /// reload always reads the value the user last set, not the stale pre-save value.
    func waitForPendingSave() async {
        await pendingSaveTask?.value
    }

    /// Persist the current priority immediately.
    func savePriority() async {
        // Snapshot priority before any suspension so a later scheduled save can't overwrite
        // this task's value with a stale one if the task was cancelled mid-flight.
        let capturedPriority = priority
        let existing = await settingsManager.loadPodcastDownloadSettings(podcastId: podcast.id)
        guard !Task.isCancelled else { return }
        // Preserve all other override fields; only update priority.
        let updated = PodcastDownloadSettings(
            podcastId: podcast.id,
            autoDownloadEnabled: existing?.autoDownloadEnabled,
            wifiOnly: existing?.wifiOnly,
            retentionPolicy: existing?.retentionPolicy,
            updateFrequency: existing?.updateFrequency,
            priority: capturedPriority
        )
        await settingsManager.updatePodcastDownloadSettings(podcastId: podcast.id, updated)
        guard !Task.isCancelled else { return }
        Self.logger.debug("Saved priority \(capturedPriority) for podcast \(self.podcast.id)")
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

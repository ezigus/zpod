import Foundation
import CoreModels

/// Protocol for new episode detection notifications
@MainActor
public protocol NewEpisodeDelegate: AnyObject {
    func onNewEpisodeDetected(episode: Episode, podcast: Podcast)
}

/// Service for handling automatic downloads when new episodes are detected
@MainActor
public class AutoDownloadService: NewEpisodeDelegate {
    private let queueManager: DownloadQueueManaging
    private var autoDownloadSettings: [String: Bool] = [:]   // podcastId -> enabled
    private var podcastPriorities: [String: Int] = [:]        // podcastId -> -10..+10

    public init(queueManager: DownloadQueueManaging) {
        self.queueManager = queueManager
    }

    /// Enable or disable auto-download for a specific podcast
    public func setAutoDownload(enabled: Bool, for podcastId: String) {
        autoDownloadSettings[podcastId] = enabled
    }

    /// Set the download priority for a specific podcast (-10..+10, default 0)
    public func setPriority(_ priority: Int, for podcastId: String) {
        podcastPriorities[podcastId] = max(-10, min(10, priority))
    }

    /// Called when a new episode is detected for a subscribed podcast
    public func onNewEpisodeDetected(episode: Episode, podcast: Podcast) {
        guard shouldAutoDownload(for: podcast) else { return }

        let priority = calculateAutoPriority(for: podcast)
        let priorityEnum = convertPriorityToEnum(priority)
        let task = DownloadTask(
            id: generateTaskId(for: episode),
            episodeId: episode.id,
            podcastId: podcast.id,
            audioURL: episode.audioURL ?? URL(string: "https://example.com/default.mp3")!,
            title: episode.title,
            estimatedSize: episode.duration.map { Int64($0 * 1024 * 1024) },
            priority: priorityEnum
        )

        queueManager.addToQueue(task)
    }

    // MARK: - Public Configuration

    public func getAutoDownloadSetting(for podcastId: String) -> Bool {
        return autoDownloadSettings[podcastId] ?? false
    }

    public func getPriority(for podcastId: String) -> Int {
        return podcastPriorities[podcastId] ?? 0
    }

    // MARK: - Private Methods

    private func shouldAutoDownload(for podcast: Podcast) -> Bool {
        if let explicitSetting = autoDownloadSettings[podcast.id] {
            return explicitSetting
        }
        return podcast.isSubscribed
    }

    /// Returns the stored per-podcast priority (-10..+10), defaulting to 0.
    private func calculateAutoPriority(for podcast: Podcast) -> Int {
        return podcastPriorities[podcast.id] ?? 0
    }

    /// Maps a -10..+10 priority integer to a DownloadPriority enum.
    /// Negative values → .low, zero → .normal, positive → .high.
    static func convertPriorityToEnum(_ priority: Int) -> DownloadPriority {
        if priority < 0 { return .low }
        if priority > 0 { return .high }
        return .normal
    }

    // Keep private instance wrapper for internal call sites
    private func convertPriorityToEnum(_ priority: Int) -> DownloadPriority {
        AutoDownloadService.convertPriorityToEnum(priority)
    }

    private func generateTaskId(for episode: Episode) -> String {
        return "auto_\(episode.id)_\(Date().timeIntervalSince1970)"
    }
}
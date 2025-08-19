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
    private var autoDownloadSettings: [String: Bool] = [:] // podcastId -> enabled
    
    public init(queueManager: DownloadQueueManaging) {
        self.queueManager = queueManager
    }
    
    /// Enable or disable auto-download for a specific podcast
    public func setAutoDownload(enabled: Bool, for podcastId: String) {
        autoDownloadSettings[podcastId] = enabled
    }
    
    /// Called when a new episode is detected for a subscribed podcast
    public func onNewEpisodeDetected(episode: Episode, podcast: Podcast) {
        // Check if auto-download is enabled for this podcast
        guard shouldAutoDownload(for: podcast) else { return }
        
        // Create download task with appropriate priority
        let priority = calculateAutoPriority(for: podcast)
        let task = DownloadTask(
            id: generateTaskId(for: episode),
            episodeId: episode.id,
            podcastId: podcast.id,
            state: .pending,
            priority: priority
        )
        
        queueManager.addToQueue(task)
    }
    
    // MARK: - Public Configuration
    
    public func getAutoDownloadSetting(for podcastId: String) -> Bool {
        return autoDownloadSettings[podcastId] ?? false
    }
    
    // MARK: - Private Methods
    
    private func shouldAutoDownload(for podcast: Podcast) -> Bool {
        // Check explicit auto-download setting first
        if let explicitSetting = autoDownloadSettings[podcast.id] {
            return explicitSetting
        }
        
        // Fallback to subscription status
        return podcast.isSubscribed
    }
    
    private func calculateAutoPriority(for podcast: Podcast) -> Int {
        // Default auto-download priority (medium)
        // Future: could be configured per podcast based on user preferences
        return 5
    }
    
    private func generateTaskId(for episode: Episode) -> String {
        return "auto_\(episode.id)_\(Date().timeIntervalSince1970)"
    }
}
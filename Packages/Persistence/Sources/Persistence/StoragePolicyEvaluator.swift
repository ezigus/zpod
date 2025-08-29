import Foundation
import CoreModels

/// Storage policy types for episode retention
public enum StoragePolicy: Codable, Equatable, Sendable {
    case keepLatest(count: Int)
    case deleteOlderThan(date: Date)
    case keepUnplayedOnly
    case custom(rule: String)
}

/// Actions that can be taken on episodes based on storage policies
public enum StorageAction: Equatable, Sendable {
    case deleteEpisode(episodeId: String)
    case archiveEpisode(episodeId: String)
}

/// Protocol for evaluating storage policies
public protocol StoragePolicyEvaluating: Sendable {
    func evaluatePolicy(_ policy: StoragePolicy, for episodes: [Episode]) async -> [StorageAction]
    func evaluateRetentionPolicies(for podcastId: String) async -> [StorageAction]
    func scheduleCleanup() async
}

/// Implementation of storage policy evaluator
public actor StoragePolicyEvaluator: StoragePolicyEvaluating {
    
    public init() {}
    
    public func evaluatePolicy(_ policy: StoragePolicy, for episodes: [Episode]) async -> [StorageAction] {
        switch policy {
        case .keepLatest(let count):
            return evaluateKeepLatestPolicy(count: count, episodes: episodes)
            
        case .deleteOlderThan(let date):
            return evaluateDeleteOlderThanPolicy(cutoffDate: date, episodes: episodes)
            
        case .keepUnplayedOnly:
            return evaluateKeepUnplayedOnlyPolicy(episodes: episodes)
            
        case .custom(_):
            // Future implementation for custom rules
            return []
        }
    }
    
    public func evaluateRetentionPolicies(for podcastId: String) async -> [StorageAction] {
        // For now, return empty actions
        // Future: Load podcast-specific policies and downloaded episodes
        return []
    }
    
    public func scheduleCleanup() async {
        // Future: Schedule background cleanup tasks
        // For now, this is a stub
    }
    
    // MARK: - Private Policy Evaluators
    
    private func evaluateKeepLatestPolicy(count: Int, episodes: [Episode]) -> [StorageAction] {
        // Sort episodes by publication date (newest first)
        let sortedEpisodes = episodes.sorted { episode1, episode2 in
            guard let date1 = episode1.pubDate, let date2 = episode2.pubDate else {
                // Episodes without dates go to the end
                return episode1.pubDate != nil
            }
            return date1 > date2
        }
        
        // Mark episodes beyond the keep count for deletion
        if sortedEpisodes.count > count {
            let episodesToDelete = Array(sortedEpisodes.dropFirst(count))
            return episodesToDelete.map { .deleteEpisode(episodeId: $0.id) }
        }
        
        return []
    }
    
    private func evaluateDeleteOlderThanPolicy(cutoffDate: Date, episodes: [Episode]) -> [StorageAction] {
        return episodes.compactMap { episode in
            guard let pubDate = episode.pubDate, pubDate < cutoffDate else {
                return nil
            }
            return .deleteEpisode(episodeId: episode.id)
        }
    }
    
    private func evaluateKeepUnplayedOnlyPolicy(episodes: [Episode]) -> [StorageAction] {
        return episodes.compactMap { episode in
            return episode.isPlayed ? .deleteEpisode(episodeId: episode.id) : nil
        }
    }
}

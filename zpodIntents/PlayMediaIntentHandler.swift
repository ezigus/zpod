//
//  PlayMediaIntentHandler.swift
//  zpodIntents
//
//  Created for Issue 02.1.8: CarPlay Siri Integration
//

import Intents
import OSLog

@available(iOS 14.0, *)
class PlayMediaIntentHandler: NSObject, INPlayMediaIntentHandling {
    
    private static let logger = Logger(subsystem: "us.zig.zpod", category: "PlayMediaIntentHandler")
    
    // MARK: - Intent Resolution
    
    func resolveMediaItems(
        for intent: INPlayMediaIntent,
        with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void
    ) {
        guard let mediaSearch = intent.mediaSearch else {
            Self.logger.info("No media search provided in intent")
            completion([.unsupported()])
            return
        }
        
        Self.logger.info("Resolving media search: \(String(describing: mediaSearch))")
        
        // Search for matching episodes/podcasts
        let mediaItems = searchMedia(for: mediaSearch)
        
        if mediaItems.isEmpty {
            Self.logger.warning("No media items found for search")
            completion([.unsupported()])
        } else if mediaItems.count == 1 {
            Self.logger.info("Found single match: \(mediaItems[0].title ?? "unknown")")
            completion([.success(with: mediaItems[0])])
        } else {
            Self.logger.info("Found \(mediaItems.count) matches, requesting disambiguation")
            completion([.disambiguation(with: mediaItems)])
        }
    }
    
    // MARK: - Intent Handling
    
    func handle(
        intent: INPlayMediaIntent,
        completion: @escaping (INPlayMediaIntentResponse) -> Void
    ) {
        guard let mediaItem = intent.mediaItems?.first else {
            Self.logger.error("No media item in intent")
            completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        guard let identifier = mediaItem.identifier else {
            Self.logger.error("Media item has no identifier")
            completion(INPlayMediaIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        Self.logger.info("Starting playback for: \(mediaItem.title ?? "unknown") (ID: \(identifier))")
        
        // Signal main app to start playback
        // This would typically use app groups or URL schemes to communicate
        let userActivity = NSUserActivity(activityType: "us.zig.zpod.playEpisode")
        userActivity.userInfo = ["episodeId": identifier]
        
        let response = INPlayMediaIntentResponse(code: .handleInApp, userActivity: userActivity)
        completion(response)
    }
    
    // MARK: - Media Search
    
    private func searchMedia(for search: INMediaSearch) -> [INMediaItem] {
        var results: [INMediaItem] = []
        
        // Extract search parameters
        let mediaName = search.mediaName
        let mediaType = search.mediaType
        let reference = search.reference
        
        Self.logger.info("Search params - name: \(mediaName ?? "nil"), type: \(String(describing: mediaType)), reference: \(String(describing: reference))")
        
        // TODO: Implement actual search logic
        // This requires:
        // 1. Access to podcast/episode data (via app groups or shared framework)
        // 2. Fuzzy matching algorithm
        // 3. Temporal query parsing ("latest", "newest")
        // 4. Ranking/scoring for best matches
        
        // For now, return empty to prevent crashes
        // Real implementation would query PodcastManaging/EpisodeRepository
        
        return results
    }
    
    // MARK: - Confirm Intent
    
    func confirm(
        intent: INPlayMediaIntent,
        completion: @escaping (INPlayMediaIntentResponse) -> Void
    ) {
        // Confirm we can handle this intent
        Self.logger.info("Confirming intent can be handled")
        completion(INPlayMediaIntentResponse(code: .ready, userActivity: nil))
    }
}

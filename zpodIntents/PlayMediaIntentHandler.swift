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
    // Extract search parameters
    let mediaName = search.mediaName
    let mediaType = search.mediaType
    let reference = search.reference

    Self.logger.info(
      "Search params - name: \(mediaName ?? "nil"), type: \(String(describing: mediaType)), reference: \(String(describing: reference))"
    )

    // Load podcast data from shared storage (App Groups)
    // Note: This is a stub that would need actual implementation with App Groups
    // For now, returning empty array until App Groups are configured
    guard let query = mediaName, !query.isEmpty else {
      Self.logger.warning("No media name provided in search")
      return []
    }

    // Parse temporal references
    #if canImport(SharedUtilities)
      import SharedUtilities
      let temporalRef = SiriMediaSearch.parseTemporalReference(query)
      Self.logger.info("Temporal reference: \(String(describing: temporalRef))")
    #endif

    // TODO: Implement actual search when App Groups are configured
    // Required steps:
    // 1. Load podcasts from shared UserDefaults or file storage
    // 2. Use SiriMediaSearch.fuzzyMatch() to find matching podcasts/episodes
    // 3. Filter by temporal reference if present (latest/oldest)
    // 4. Convert matches to INMediaItem array

    Self.logger.warning("Search implementation pending App Groups configuration")

    // Example architecture (requires App Groups setup):
    // let sharedDefaults = UserDefaults(suiteName: "group.us.zig.zpod")
    // if let data = sharedDefaults?.data(forKey: "podcasts"),
    //    let podcasts = try? JSONDecoder().decode([PodcastData].self, from: data) {
    //
    //     #if canImport(SharedUtilities)
    //     import SharedUtilities
    //
    //     var matches: [(podcast: PodcastData, episode: EpisodeData?, score: Double)] = []
    //
    //     for podcast in podcasts {
    //         let podcastScore = SiriMediaSearch.fuzzyMatch(query: query, target: podcast.title)
    //         if podcastScore > 0.5 {
    //             for episode in podcast.episodes {
    //                 let episodeScore = SiriMediaSearch.fuzzyMatch(query: query, target: episode.title)
    //                 let finalScore = max(podcastScore, episodeScore)
    //                 if finalScore > 0.5 {
    //                     matches.append((podcast, episode, finalScore))
    //                 }
    //             }
    //         }
    //     }
    //
    //     // Sort by score and apply temporal filtering if needed
    //     matches.sort { $0.score > $1.score }
    //     if let temporal = temporalRef {
    //         matches = filterByTemporal(matches, reference: temporal)
    //     }
    //
    //     // Convert top results to INMediaItem
    //     return matches.prefix(5).map { match in
    //         INMediaItem(
    //             identifier: match.episode.id,
    //             title: match.episode.title,
    //             type: .podcastEpisode,
    //             artwork: nil
    //         )
    //     }
    //     #endif
    // }

    return []
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

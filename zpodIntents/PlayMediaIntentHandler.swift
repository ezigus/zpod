//
//  PlayMediaIntentHandler.swift
//  zpodIntents
//
//  Created for Issue 02.1.8: CarPlay Siri Integration
//

import Intents
import OSLog
import SharedUtilities

@available(iOS 14.0, *)
class PlayMediaIntentHandler: NSObject, INPlayMediaIntentHandling {

  private static let logger = Logger(subsystem: "us.zig.zpod", category: "PlayMediaIntentHandler")
  private static let appGroupSuite = "group.us.zig.zpod"

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

    guard let query = mediaName, !query.isEmpty else {
      Self.logger.warning("No media name provided in search")
      return []
    }

    let temporalRef = SiriMediaSearch.parseTemporalReference(query)
    Self.logger.info("Temporal reference: \(String(describing: temporalRef))")

    let snapshots = loadSnapshots()
    guard !snapshots.isEmpty else {
      Self.logger.warning("No podcast snapshots available for Siri search")
      return []
    }

    // Determine whether the user explicitly asked for a podcast show.
    let wantsPodcastShow = (mediaType == .podcastShow)

    if wantsPodcastShow {
      return resolvePodcasts(query: query, snapshots: snapshots)
    }

    return resolveEpisodes(
      query: query,
      snapshots: snapshots,
      temporalReference: temporalRef
    )
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

  // MARK: - Snapshot Loading

  private func loadSnapshots() -> [SiriPodcastSnapshot] {
    if #available(iOS 14.0, *) {
      let shared = SiriMediaLibrary.loadFromSharedContainer(suiteName: Self.appGroupSuite)
      if !shared.isEmpty {
        return shared
      }
    }

    // Development fallback: allow tests to inject data via standard defaults
    if let defaults = UserDefaults(suiteName: "dev.us.zig.zpod"),
      let data = defaults.data(forKey: SiriMediaLibrary.storageKey),
      let snapshots = try? JSONDecoder().decode([SiriPodcastSnapshot].self, from: data)
    {
      return snapshots
    }

    return []
  }

  private func resolveEpisodes(
    query: String,
    snapshots: [SiriPodcastSnapshot],
    temporalReference: SiriMediaSearch.TemporalReference?
  ) -> [INMediaItem] {
    var matches: [EpisodeMatch] = []

    for podcast in snapshots {
      let podcastScore = SiriMediaSearch.fuzzyMatch(query: query, target: podcast.title)

      for episode in podcast.episodes {
        let episodeScore = SiriMediaSearch.fuzzyMatch(query: query, target: episode.title)
        let finalScore = max(podcastScore, episodeScore)

        if finalScore >= 0.5 {
          matches.append(EpisodeMatch(snapshot: episode, podcast: podcast, score: finalScore))
        }
      }
    }

    if let temporalReference {
      matches = applyTemporalFilter(matches, reference: temporalReference)
    }

    let topMatches = matches
      .sorted { lhs, rhs in
        lhs.score == rhs.score
          ? (lhs.snapshot.publishedAt ?? .distantPast) > (rhs.snapshot.publishedAt ?? .distantPast)
          : lhs.score > rhs.score
      }
      .prefix(5)

    return topMatches.map { match in
      INMediaItem(
        identifier: match.snapshot.id,
        title: match.snapshot.title,
        type: .podcastEpisode,
        artwork: nil
      )
    }
  }

  private func resolvePodcasts(
    query: String,
    snapshots: [SiriPodcastSnapshot]
  ) -> [INMediaItem] {
    let matches = snapshots
      .map { snapshot -> (SiriPodcastSnapshot, Double) in
        (snapshot, SiriMediaSearch.fuzzyMatch(query: query, target: snapshot.title))
      }
      .filter { $0.1 >= 0.5 }
      .sorted { lhs, rhs in lhs.1 > rhs.1 }
      .prefix(5)

    return matches.map { snapshot, _ in
      INMediaItem(
        identifier: snapshot.id,
        title: snapshot.title,
        type: .podcastShow,
        artwork: nil
      )
    }
  }

  private func applyTemporalFilter(
    _ matches: [EpisodeMatch],
    reference: SiriMediaSearch.TemporalReference
  ) -> [EpisodeMatch] {
    switch reference {
    case .latest:
      return matches
        .grouped(by: { $0.podcast.id })
        .compactMap { _, group in
          group.max(by: { (lhs, rhs) -> Bool in
            (lhs.snapshot.publishedAt ?? .distantPast) < (rhs.snapshot.publishedAt ?? .distantPast)
          })
        }
    case .oldest:
      return matches
        .grouped(by: { $0.podcast.id })
        .compactMap { _, group in
          group.min(by: { (lhs, rhs) -> Bool in
            (lhs.snapshot.publishedAt ?? .distantFuture) < (rhs.snapshot.publishedAt ?? .distantFuture)
          })
        }
    }
  }
}

// MARK: - Helpers

private extension Array {
  func grouped<Key: Hashable>(by keyForValue: (Element) -> Key) -> [Key: [Element]] {
    reduce(into: [:]) { partialResult, element in
      let key = keyForValue(element)
      partialResult[key, default: []].append(element)
    }
  }
}

@available(iOS 14.0, *)
private struct EpisodeMatch {
  let snapshot: SiriEpisodeSnapshot
  let podcast: SiriPodcastSnapshot
  let score: Double
}

import Foundation

/// Provides higher-level search utilities for Siri/CarPlay media queries backed by
/// previously materialized `SiriPodcastSnapshot` data.
@available(iOS 14.0, *)
public struct SiriMediaResolver {
    public struct EpisodeMatch: Sendable, Equatable {
        public let podcast: SiriPodcastSnapshot
        public let episode: SiriEpisodeSnapshot
        public let score: Double

        public init(podcast: SiriPodcastSnapshot, episode: SiriEpisodeSnapshot, score: Double) {
            self.podcast = podcast
            self.episode = episode
            self.score = score
        }
    }

    private let podcasts: [SiriPodcastSnapshot]
    private let resultLimit: Int

    public init(podcasts: [SiriPodcastSnapshot], resultLimit: Int = 5) {
        self.podcasts = podcasts
        self.resultLimit = resultLimit
    }

    /// Performs a fuzzy search across podcast episodes using the configured snapshots.
    public func searchEpisodes(
        query: String,
        temporalReference: SiriMediaSearch.TemporalReference?
    ) -> [EpisodeMatch] {
        var matches: [EpisodeMatch] = []

        for podcast in podcasts {
            let podcastScore = SiriMediaSearch.fuzzyMatch(query: query, target: podcast.title)

            for episode in podcast.episodes {
                let episodeScore = SiriMediaSearch.fuzzyMatch(query: query, target: episode.title)
                let finalScore = max(podcastScore, episodeScore)

                guard finalScore >= 0.5 else { continue }

                matches.append(
                    EpisodeMatch(
                        podcast: podcast,
                        episode: episode,
                        score: finalScore
                    )
                )
            }
        }

        if let temporalReference {
            matches = applyTemporalFilter(matches, reference: temporalReference)
        }

        return matches
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return (lhs.episode.publishedAt ?? .distantPast) > (rhs.episode.publishedAt ?? .distantPast)
                }
                return lhs.score > rhs.score
            }
            .prefix(resultLimit)
            .map { $0 }
    }

    /// Performs a fuzzy search for podcast-level matches.
    public func searchPodcasts(query: String) -> [(podcast: SiriPodcastSnapshot, score: Double)] {
        podcasts
            .map { snapshot in
                (podcast: snapshot, score: SiriMediaSearch.fuzzyMatch(query: query, target: snapshot.title))
            }
            .filter { $0.score >= 0.5 }
            .sorted { lhs, rhs in lhs.score > rhs.score }
            .prefix(resultLimit)
            .map { $0 }
    }

    /// Loads snapshots from the primary shared container, optionally falling back to a development suite.
    public static func loadResolver(
        primarySuite: String,
        devSuite: String? = nil,
        resultLimit: Int = 5
    ) -> SiriMediaResolver? {
        let primary = SiriMediaLibrary.loadFromSharedContainer(suiteName: primarySuite)
        if !primary.isEmpty {
            return SiriMediaResolver(podcasts: primary, resultLimit: resultLimit)
        }

        if let devSuite, let devDefaults = UserDefaults(suiteName: devSuite) {
            do {
                let snapshots = try SiriMediaLibrary.load(from: devDefaults)
                if !snapshots.isEmpty {
                    return SiriMediaResolver(podcasts: snapshots, resultLimit: resultLimit)
                }
            } catch {
                // Ignore decode failures; caller will handle nil.
            }
        }

        return nil
    }

    private func applyTemporalFilter(
        _ matches: [EpisodeMatch],
        reference: SiriMediaSearch.TemporalReference
    ) -> [EpisodeMatch] {
        switch reference {
        case .latest:
            guard let latest = matches.max(by: { ($0.episode.publishedAt ?? .distantPast) < ($1.episode.publishedAt ?? .distantPast) }) else {
                return matches
            }
            return [latest]
        case .oldest:
            guard let oldest = matches.min(by: { ($0.episode.publishedAt ?? .distantPast) < ($1.episode.publishedAt ?? .distantPast) }) else {
                return matches
            }
            return [oldest]
        }
    }
}

//
//  EpisodeEntity.swift
//  zpod
//
//  App Intents replacement for INMediaItem resolution (issue #583).
//

import AppIntents
import Foundation
import SharedUtilities

/// An episode, as the system understands it.
///
/// Replaces the `INMediaItem` values `PlayMediaIntentHandler` builds. Where SiriKit could
/// only return opaque media items, an `AppEntity` is queryable by Siri, Shortcuts and
/// Spotlight, which is what lets the action appear outside a voice request.
@available(iOS 18.0, *)
struct EpisodeEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Episode"
    static let defaultQuery = EpisodeQuery()

    let id: String
    let title: String
    let podcastTitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(podcastTitle)")
    }
}

/// Backs `EpisodeEntity` with the same snapshot search the SiriKit handler uses, so both
/// paths resolve identically while the legacy handler remains in place.
@available(iOS 18.0, *)
struct EpisodeQuery: EntityStringQuery {

    func entities(for identifiers: [String]) async throws -> [EpisodeEntity] {
        guard let resolver = Self.resolver() else { return [] }
        let wanted = Set(identifiers)

        return resolver.searchEpisodes(query: "", temporalReference: nil)
            .filter { wanted.contains($0.episode.id) }
            .map(EpisodeEntity.init(match:))
    }

    func entities(matching string: String) async throws -> [EpisodeEntity] {
        guard let resolver = Self.resolver() else { return [] }
        let temporal = SiriMediaSearch.parseTemporalReference(string)

        return resolver
            .searchEpisodes(query: string, temporalReference: temporal)
            .map(EpisodeEntity.init(match:))
    }

    func suggestedEntities() async throws -> [EpisodeEntity] {
        guard let resolver = Self.resolver() else { return [] }
        return resolver.searchEpisodes(query: "", temporalReference: nil).map(EpisodeEntity.init(match:))
    }

    private static func resolver() -> SiriMediaResolver? {
        SiriMediaResolver.loadResolver(
            primarySuite: AppGroup.suiteName,
            devSuite: AppGroup.devSuiteName
        )
    }
}

@available(iOS 18.0, *)
extension EpisodeEntity {
    init(match: SiriMediaResolver.EpisodeMatch) {
        self.init(id: match.episode.id, title: match.episode.title, podcastTitle: match.podcast.title)
    }
}

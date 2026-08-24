//
//  PlayEpisodeIntent.swift
//  zpod
//
//  App Intents replacement for INPlayMediaIntent (issue #583).
//

import AppIntents
import Foundation

/// Plays an episode. The App Intents counterpart of `PlayMediaIntentHandler`.
///
/// Conforming to `AudioPlaybackIntent` tells the system this starts audio, which is what
/// makes it eligible for the Action button, Shortcuts and Spotlight — the surfaces the
/// legacy `INPlayMediaIntent` path cannot reach.
///
/// The legacy handler is intentionally left in place for older systems; this type is
/// additive.
@available(iOS 18.0, *)
struct PlayEpisodeIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play Episode"
    static let description = IntentDescription("Plays a podcast episode in zpod.")

    /// Playback has to happen in the app that owns the audio session.
    static let openAppWhenRun = true

    @Parameter(title: "Episode", requestValueDialog: "Which episode?")
    var episode: EpisodeEntity

    init() {}

    init(episode: EpisodeEntity) {
        self.episode = episode
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$episode)")
    }

    func perform() async throws -> some IntentResult {
        // Reuses the existing playback request contract rather than introducing a second
        // path: the app already knows how to start playback from an episode identifier.
        NotificationCenter.default.post(
            name: .zpodPlayEpisodeRequested,
            object: nil,
            userInfo: [PlayEpisodeRequest.episodeIDKey: episode.id]
        )
        return .result()
    }
}

/// The request the intent raises and the app fulfils.
public enum PlayEpisodeRequest {
    public static let episodeIDKey = "episodeId"
}

extension Notification.Name {
    /// Posted when an App Intent asks for playback. Observed by the app, which starts
    /// playback exactly as it does for the existing `us.zig.zpod.playEpisode` activity.
    public static let zpodPlayEpisodeRequested = Notification.Name("us.zig.zpod.playEpisodeRequested")
}

import Foundation
import CoreModels

/// Well-known, stable test episodes for use in test Given setup.
///
/// All fixtures use `example.com` domain; never reference real podcast feeds.
/// Fixtures are deterministic value types — they do not persist unless explicitly saved.
public enum EpisodeFixtures {
    // MARK: - Swift Talk episodes

    public static let swiftConcurrency = Episode(
        id: "swift-talk-001",
        title: "Understanding Swift Concurrency",
        podcastID: PodcastFixtures.swiftTalk.id,
        podcastTitle: PodcastFixtures.swiftTalk.title,
        duration: 1_800,
        description: "Quick overview of actors and structured concurrency."
    )

    public static let swiftUILayouts = Episode(
        id: "swift-talk-002",
        title: "SwiftUI Layout Techniques",
        podcastID: PodcastFixtures.swiftTalk.id,
        podcastTitle: PodcastFixtures.swiftTalk.title,
        duration: 2_100,
        description: "Deep dive into SwiftUI layout APIs."
    )

    // MARK: - Swift Over Coffee episodes

    public static let swiftOverCoffeeLatestNews = Episode(
        id: "swift-over-coffee-001",
        title: "Swift News Roundup",
        podcastID: PodcastFixtures.swiftOverCoffee.id,
        podcastTitle: PodcastFixtures.swiftOverCoffee.title,
        duration: 1_500,
        description: "Discussing the latest Swift community news."
    )

    // MARK: - ATP episodes

    public static let atpIntro = Episode(
        id: "atp-001",
        title: "Introduction to ATP",
        podcastID: PodcastFixtures.accidentalTechPodcast.id,
        podcastTitle: PodcastFixtures.accidentalTechPodcast.title,
        duration: 3_600,
        description: "First episode of the Accidental Tech Podcast."
    )

    // MARK: - Convenience collections

    /// All Swift Talk fixture episodes.
    public static let swiftTalkEpisodes: [Episode] = [swiftConcurrency, swiftUILayouts]

    /// All Swift Over Coffee fixture episodes.
    public static let swiftOverCoffeeEpisodes: [Episode] = [swiftOverCoffeeLatestNews]

    /// All ATP fixture episodes.
    public static let atpEpisodes: [Episode] = [atpIntro]

    /// All fixture episodes across all podcasts.
    public static let all: [Episode] = swiftTalkEpisodes + swiftOverCoffeeEpisodes + atpEpisodes
}

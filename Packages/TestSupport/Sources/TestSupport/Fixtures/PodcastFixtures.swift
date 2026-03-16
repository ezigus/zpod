import Foundation
import CoreModels

/// Well-known, stable test podcasts for use in test Given setup.
///
/// All fixtures use `example.com` domain; never reference real podcast feeds.
/// Fixtures are deterministic value types — they do not persist unless explicitly saved.
///
/// ## Feed URL force-unwraps
/// `Podcast.feedURL` is a non-optional `URL`. The force-unwrap on `URL(string:)!` is
/// intentional: all feed URLs here are known-valid literals. A runtime crash on init
/// is a clear signal that a URL was accidentally broken during editing.
public enum PodcastFixtures {
    public static let swiftTalk = Podcast(
        id: "swift-talk",
        title: "Swift Talk",
        author: "objc.io",
        description: "Deep dives into advanced Swift topics.",
        artworkURL: URL(string: "https://example.com/swift-talk.png"),
        feedURL: URL(string: "https://example.com/swift-talk.rss")!,
        categories: ["Development"],
        episodes: [],
        isSubscribed: true
    )

    public static let swiftOverCoffee = Podcast(
        id: "swift-over-coffee",
        title: "Swift Over Coffee",
        author: "Paul Hudson & Sean Allen",
        description: "Swift news and discussion over coffee.",
        artworkURL: URL(string: "https://example.com/swift-over-coffee.png"),
        feedURL: URL(string: "https://example.com/swift-over-coffee.rss")!,
        categories: ["Development", "News"],
        episodes: [],
        isSubscribed: false
    )

    public static let accidentalTechPodcast = Podcast(
        id: "accidental-tech-podcast",
        title: "Accidental Tech Podcast",
        author: "Casey Liss, Marco Arment, John Siracusa",
        description: "Apple, technology, and programming news commentary.",
        artworkURL: URL(string: "https://example.com/atp.png"),
        feedURL: URL(string: "https://example.com/atp.rss")!,
        categories: ["Technology"],
        episodes: [],
        isSubscribed: true
    )

    /// Returns all three standard fixtures as an array, suitable for seeding an in-memory store.
    public static let all: [Podcast] = [swiftTalk, swiftOverCoffee, accidentalTechPodcast]
}

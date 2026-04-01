import Foundation

/// Represents a podcast search result from an external directory (e.g. iTunes, PodcastIndex).
public struct DirectorySearchResult: Codable, Equatable, Sendable {
    /// Provider-specific identifier (e.g. iTunes collectionId).
    public let id: String
    /// Podcast title.
    public let title: String
    /// Author or publisher name.
    public let author: String?
    /// Short podcast description.
    public let description: String?
    /// URL to podcast artwork.
    public let artworkURL: URL?
    /// RSS feed URL — used to subscribe and parse episodes.
    public let feedURL: URL
    /// Genre/category labels.
    public let genres: [String]
    /// Total episode count as reported by the directory (nil if unknown).
    public let episodeCount: Int?
    /// Source identifier: "itunes", "podcastindex", etc.
    public let provider: String

    public init(
        id: String,
        title: String,
        author: String? = nil,
        description: String? = nil,
        artworkURL: URL? = nil,
        feedURL: URL,
        genres: [String] = [],
        episodeCount: Int? = nil,
        provider: String
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.description = description
        self.artworkURL = artworkURL
        self.feedURL = feedURL
        self.genres = genres
        self.episodeCount = episodeCount
        self.provider = provider
    }

    /// Converts this directory result to a `Podcast` suitable for display and subscription.
    public func toPodcast() -> Podcast {
        Podcast(
            id: feedURL.absoluteString,
            title: title,
            author: author,
            description: description,
            artworkURL: artworkURL,
            feedURL: feedURL,
            categories: genres,
            episodes: [],
            isSubscribed: false
        )
    }
}

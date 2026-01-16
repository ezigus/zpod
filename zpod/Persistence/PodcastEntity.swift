import Foundation
import SwiftData
import CoreModels

/// SwiftData persistent model for `Podcast`.
///
/// Maps the domain `Podcast` struct to a SwiftData-managed entity for persistent storage.
/// Episodes are kept as transient (not persisted) initially - they're fetched from RSS feeds.
@available(iOS 17, macOS 14, watchOS 10, *)
@Model
public final class PodcastEntity {
    /// Unique identifier (matches Podcast.id)
    @Attribute(.unique) public var id: String

    /// Podcast title
    public var title: String

    /// Author or publisher name
    public var author: String?

    /// Podcast description (renamed from 'description' which is reserved in SwiftData)
    public var podcastDescription: String?

    /// URL to podcast artwork image (stored as string for SwiftData compatibility)
    public var artworkURLString: String?

    /// RSS feed URL (stored as string for SwiftData compatibility)
    public var feedURLString: String

    /// List of category names
    public var categories: [String]

    /// Whether the user is subscribed to this podcast
    public var isSubscribed: Bool

    /// When the podcast was added to the library
    public var dateAdded: Date

    /// Optional folder ID for hierarchical organization
    public var folderId: String?

    /// Tag IDs for flat organization (multiple tags supported)
    public var tagIds: [String]

    /// Initializes a new PodcastEntity.
    ///
    /// - Note: Episodes are intentionally not persisted in this initial implementation.
    ///   They are fetched from RSS feeds and held in memory in the `Podcast` struct.
    public init(
        id: String,
        title: String,
        author: String? = nil,
        podcastDescription: String? = nil,
        artworkURLString: String? = nil,
        feedURLString: String,
        categories: [String] = [],
        isSubscribed: Bool = false,
        dateAdded: Date = Date(),
        folderId: String? = nil,
        tagIds: [String] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.podcastDescription = podcastDescription
        self.artworkURLString = artworkURLString
        self.feedURLString = feedURLString
        self.categories = categories
        self.isSubscribed = isSubscribed
        self.dateAdded = dateAdded
        self.folderId = folderId
        self.tagIds = tagIds
    }
}

// MARK: - Domain Conversion

extension PodcastEntity {
    /// Converts this SwiftData entity to a domain `Podcast` struct.
    ///
    /// - Parameter episodes: Episodes to include (fetched separately from RSS feed)
    /// - Returns: Domain model `Podcast`
    public func toDomain(episodes: [Episode] = []) -> Podcast {
        Podcast(
            id: id,
            title: title,
            author: author,
            description: podcastDescription,
            artworkURL: artworkURLString.flatMap { URL(string: $0) },
            feedURL: URL(string: feedURLString)!,  // feedURL is required, so force unwrap
            categories: categories,
            episodes: episodes,
            isSubscribed: isSubscribed,
            dateAdded: dateAdded,
            folderId: folderId,
            tagIds: tagIds
        )
    }

    /// Creates a PodcastEntity from a domain `Podcast`.
    ///
    /// - Parameter podcast: Domain model to convert
    /// - Returns: New PodcastEntity
    /// - Note: Episodes are not persisted in this initial implementation
    public static func fromDomain(_ podcast: Podcast) -> PodcastEntity {
        PodcastEntity(
            id: podcast.id,
            title: podcast.title,
            author: podcast.author,
            podcastDescription: podcast.description,
            artworkURLString: podcast.artworkURL?.absoluteString,
            feedURLString: podcast.feedURL.absoluteString,
            categories: podcast.categories,
            isSubscribed: podcast.isSubscribed,
            dateAdded: podcast.dateAdded,
            folderId: podcast.folderId,
            tagIds: podcast.tagIds
        )
    }

    /// Updates this entity's properties from a domain `Podcast`.
    ///
    /// - Parameter podcast: Domain model with updated values
    /// - Note: Preserves `dateAdded` from existing entity
    public func updateFrom(_ podcast: Podcast) {
        self.title = podcast.title
        self.author = podcast.author
        self.podcastDescription = podcast.description
        self.artworkURLString = podcast.artworkURL?.absoluteString
        self.feedURLString = podcast.feedURL.absoluteString
        self.categories = podcast.categories
        self.isSubscribed = podcast.isSubscribed
        // dateAdded is NOT updated - it should never change
        self.folderId = podcast.folderId
        self.tagIds = podcast.tagIds
    }
}

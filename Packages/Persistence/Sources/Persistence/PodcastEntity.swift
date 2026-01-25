import Foundation
import SwiftData
import CoreModels

/// SwiftData persistent model for `Podcast`.
///
/// Episodes are intentionally not persisted in this initial package migration.
@available(iOS 17, macOS 14, watchOS 10, *)
@Model
public final class PodcastEntity {
    @Attribute(.unique) public var id: String
    public var title: String
    public var author: String?
    public var podcastDescription: String?
    public var artworkURLString: String?
    public var feedURLString: String
    public var categories: [String]
    public var isSubscribed: Bool
    public var dateAdded: Date
    public var folderId: String?
    public var tagIds: [String]

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

@available(iOS 17, macOS 14, watchOS 10, *)
extension PodcastEntity {
    /// Convert to domain model.
    /// Falls back to a placeholder URL if the stored feedURL is invalid.
    /// Prefer `toDomainSafe()` for production code paths to skip corrupted rows.
    public func toDomain(episodes: [Episode] = []) -> Podcast {
        if let podcast = toDomainSafe(episodes: episodes) {
            return podcast
        }

        return Podcast(
            id: id,
            title: title,
            author: author,
            description: podcastDescription,
            artworkURL: artworkURLString.flatMap { URL(string: $0) },
            feedURL: URL(string: "about:blank")!,  // Corrupted feed URL fallback
            categories: categories,
            episodes: episodes,
            isSubscribed: isSubscribed,
            dateAdded: dateAdded,
            folderId: folderId,
            tagIds: tagIds
        )
    }

    /// Safe conversion that returns nil if feedURL is invalid
    /// Use this in repository queries where data corruption is possible.
    public func toDomainSafe(episodes: [Episode] = []) -> Podcast? {
        guard let feedURL = URL(string: feedURLString) else {
            // Log corruption but don't crash - skip this entity
            print("⚠️ PodcastEntity.toDomainSafe: Invalid feedURL for podcast \(id): \(feedURLString)")
            return nil
        }

        return Podcast(
            id: id,
            title: title,
            author: author,
            description: podcastDescription,
            artworkURL: artworkURLString.flatMap { URL(string: $0) },
            feedURL: feedURL,
            categories: categories,
            episodes: episodes,
            isSubscribed: isSubscribed,
            dateAdded: dateAdded,
            folderId: folderId,
            tagIds: tagIds
        )
    }

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

    public func updateFrom(_ podcast: Podcast) {
        title = podcast.title
        author = podcast.author
        podcastDescription = podcast.description
        artworkURLString = podcast.artworkURL?.absoluteString
        feedURLString = podcast.feedURL.absoluteString
        categories = podcast.categories
        isSubscribed = podcast.isSubscribed
        folderId = podcast.folderId
        tagIds = podcast.tagIds
    }
}

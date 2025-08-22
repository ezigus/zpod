@preconcurrency import Foundation

/// Represents a podcast, its metadata, and relationships to episodes and playlists.
public struct Podcast: Codable, Equatable, Sendable {
  /// Unique identifier for the podcast (e.g., feed URL or GUID).
  public let id: String
  /// Podcast title.
  public let title: String
  /// Author or publisher name.
  public let author: String?
  /// Podcast description or summary.
  public let description: String?
  /// URL to podcast artwork image.
  public let artworkURL: URL?
  /// RSS feed URL for the podcast.
  public let feedURL: URL
  /// List of category names.
  public let categories: [String]
  /// List of episodes (relationship, initially empty or loaded separately).
  public let episodes: [Episode]
  /// Whether the user is subscribed to this podcast.
  public let isSubscribed: Bool
  /// When the podcast was added to the library.
  public let dateAdded: Date
  /// Optional folder ID for hierarchical organization.
  public let folderId: String?
  /// Tag IDs for flat organization (multiple tags supported).
  public let tagIds: [String]

  public init(
    id: String,
    title: String,
    author: String? = nil,
    description: String? = nil,
    artworkURL: URL? = nil,
    feedURL: URL,
    categories: [String] = [],
    episodes: [Episode] = [],
    isSubscribed: Bool = false,
    dateAdded: Date = Date(),
    folderId: String? = nil,
    tagIds: [String] = []
  ) {
    self.id = id
    self.title = title
    self.author = author
    self.description = description
    self.artworkURL = artworkURL
    self.feedURL = feedURL
    self.categories = categories
    self.episodes = episodes
    self.isSubscribed = isSubscribed
    self.dateAdded = dateAdded
    self.folderId = folderId
    self.tagIds = tagIds
  }
}
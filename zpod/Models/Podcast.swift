import Foundation

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

  // MARK: - Codable (custom to preserve sub-second precision for dateAdded)
  private enum CodingKeys: String, CodingKey {
    case id, title, author, description, artworkURL, feedURL, categories, episodes, isSubscribed,
      dateAdded, folderId, tagIds
  }

  nonisolated(unsafe) private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    author = try container.decodeIfPresent(String.self, forKey: .author)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    artworkURL = try container.decodeIfPresent(URL.self, forKey: .artworkURL)
    feedURL = try container.decode(URL.self, forKey: .feedURL)
    categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
    episodes = try container.decodeIfPresent([Episode].self, forKey: .episodes) ?? []
    isSubscribed = try container.decodeIfPresent(Bool.self, forKey: .isSubscribed) ?? false

    // Prefer numeric seconds (exact round-trip), but support string ISO8601 (with/without fractional seconds) as fallback
    if let seconds = try? container.decode(Double.self, forKey: .dateAdded) {
      dateAdded = Date(timeIntervalSince1970: seconds)
    } else if let dateString = try? container.decode(String.self, forKey: .dateAdded) {
      if let parsed = Podcast.iso8601WithFractionalSeconds.date(from: dateString) {
        dateAdded = parsed
      } else if let parsed = ISO8601DateFormatter().date(from: dateString) {
        dateAdded = parsed
      } else {
        // Fallback to current date if unparsable (should not happen in tests)
        dateAdded = Date()
      }
    } else {
      dateAdded = try container.decode(Date.self, forKey: .dateAdded)
    }
    
    // Organization fields (optional for backward compatibility)
    folderId = try container.decodeIfPresent(String.self, forKey: .folderId)
    tagIds = try container.decodeIfPresent([String].self, forKey: .tagIds) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(title, forKey: .title)
    try container.encodeIfPresent(author, forKey: .author)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(artworkURL, forKey: .artworkURL)
    try container.encode(feedURL, forKey: .feedURL)
    try container.encode(categories, forKey: .categories)
    try container.encode(episodes, forKey: .episodes)
    try container.encode(isSubscribed, forKey: .isSubscribed)
    // Encode as numeric seconds since 1970 to preserve full precision and enable exact equality checks
    try container.encode(dateAdded.timeIntervalSince1970, forKey: .dateAdded)
    // Organization fields
    try container.encodeIfPresent(folderId, forKey: .folderId)
    try container.encode(tagIds, forKey: .tagIds)
  }
}

/// Represents a podcast episode with playback metadata
public struct Episode: Codable, Equatable, Sendable {
  public let id: String
  public let title: String
  /// Episode description or summary (may be sourced from RSS item <description> / <content:encoded> later).
  public let description: String?
  /// Optional enclosure URL (media) captured during parsing (future use: playback/download).
  public let mediaURL: URL?
  /// Episode duration in seconds (if known)
  public let duration: TimeInterval?
  /// Publication date
  public let pubDate: Date?
  /// Whether the episode has been marked as played
  public let isPlayed: Bool
  /// Current playback position in seconds
  public let playbackPosition: TimeInterval
  /// Chapters for this episode
  public let chapters: [Chapter]
  /// Parent podcast ID for settings lookup
  public let podcastId: String?

  public init(
    id: String,
    title: String,
    description: String? = nil,
    mediaURL: URL? = nil,
    duration: TimeInterval? = nil,
    pubDate: Date? = nil,
    isPlayed: Bool = false,
    playbackPosition: TimeInterval = 0,
    chapters: [Chapter] = [],
    podcastId: String? = nil
  ) {
    self.id = id
    self.title = title
    self.description = description
    self.mediaURL = mediaURL
    self.duration = duration
    self.pubDate = pubDate
    self.isPlayed = isPlayed
    self.playbackPosition = max(0, playbackPosition)
    self.chapters = chapters.sorted { $0.startTime < $1.startTime }
    self.podcastId = podcastId
  }

  /// Create a copy of the episode with updated played status
  public func withPlayedStatus(_ played: Bool) -> Episode {
    Episode(
      id: id,
      title: title,
      description: description,
      mediaURL: mediaURL,
      duration: duration,
      pubDate: pubDate,
      isPlayed: played,
      playbackPosition: playbackPosition,
      chapters: chapters,
      podcastId: podcastId
    )
  }

  /// Create a copy of the episode with updated playback position
  public func withPlaybackPosition(_ position: TimeInterval) -> Episode {
    Episode(
      id: id,
      title: title,
      description: description,
      mediaURL: mediaURL,
      duration: duration,
      pubDate: pubDate,
      isPlayed: isPlayed,
      playbackPosition: max(0, position),
      chapters: chapters,
      podcastId: podcastId
    )
  }
}

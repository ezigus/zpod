import Foundation

/// Snapshot representing a podcast that can be shared with Siri/CarPlay components.
@available(iOS 14.0, *)
public struct SiriPodcastSnapshot: Codable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let episodes: [SiriEpisodeSnapshot]

  public init(id: String, title: String, episodes: [SiriEpisodeSnapshot]) {
    self.id = id
    self.title = title
    self.episodes = episodes
  }
}

/// Snapshot representing an individual episode for Siri/CarPlay lookup.
@available(iOS 14.0, *)
public struct SiriEpisodeSnapshot: Codable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let duration: TimeInterval?
  public let playbackPosition: Int?
  public let isPlayed: Bool
  public let publishedAt: Date?

  public init(
    id: String,
    title: String,
    duration: TimeInterval? = nil,
    playbackPosition: Int? = nil,
    isPlayed: Bool = false,
    publishedAt: Date? = nil
  ) {
    self.id = id
    self.title = title
    self.duration = duration
    self.playbackPosition = playbackPosition
    self.isPlayed = isPlayed
    self.publishedAt = publishedAt
  }
}

/// Utility for persisting and loading Siri podcast snapshots from shared storage.
@available(iOS 14.0, *)
public enum SiriMediaLibrary {
  /// Default key used to persist the user's podcast library.
  public static let storageKey = "carplay.podcastSnapshots"

  /// Saves the supplied podcast snapshots into the provided `UserDefaults` container.
  public static func save(
    _ podcasts: [SiriPodcastSnapshot],
    to defaults: UserDefaults,
    encoder: JSONEncoder = JSONEncoder()
  ) throws {
    let data = try encoder.encode(podcasts)
    defaults.set(data, forKey: storageKey)
    defaults.synchronize()
  }

  /// Loads podcast snapshots from the provided `UserDefaults` container.
  public static func load(
    from defaults: UserDefaults,
    decoder: JSONDecoder = JSONDecoder()
  ) throws -> [SiriPodcastSnapshot] {
    guard let data = defaults.data(forKey: storageKey) else {
      return []
    }
    return try decoder.decode([SiriPodcastSnapshot].self, from: data)
  }

  /// Convenience for reading from the shared app-group container.
  public static func loadFromSharedContainer(
    suiteName: String
  ) -> [SiriPodcastSnapshot] {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      return []
    }

    do {
      return try load(from: defaults)
    } catch {
      return []
    }
  }
}

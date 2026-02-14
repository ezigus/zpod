import CoreModels
import Foundation
import OSLog
import SwiftData

/// Protocol for storing individual episode state snapshots.
public protocol EpisodeRepository: Sendable {
  func saveEpisode(_ episode: Episode) async throws
  func loadEpisode(id: String) async throws -> Episode?
}

/// Provides read-only access to persisted episode metadata for consumers such as Siri.
public protocol EpisodeSnapshotProviding: Sendable {
  func allEpisodes() -> [Episode]
  func episodes(forPodcastId podcastId: String) -> [Episode]
}

@available(iOS 17, macOS 14, watchOS 10, *)
public final class SwiftDataEpisodeSnapshotRepository: EpisodeSnapshotProviding, @unchecked Sendable {
  private let serialQueue: DispatchQueue
  private let modelContext: ModelContext
  private let logger = Logger(subsystem: "us.zig.zpod.persistence", category: "SwiftDataEpisodeSnapshotRepository")

  public init(modelContainer: ModelContainer) {
    let queue = DispatchQueue(label: "us.zig.zpod.SwiftDataEpisodeSnapshotRepository")
    self.serialQueue = queue

    var context: ModelContext?
    queue.sync {
      context = ModelContext(modelContainer)
    }
    guard let context else {
      fatalError("Failed to create ModelContext for SwiftDataEpisodeSnapshotRepository")
    }
    self.modelContext = context
  }

  public func allEpisodes() -> [Episode] {
    serialQueue.sync {
      fetchAllEpisodesUnlocked()
    }
  }

  public func episodes(forPodcastId podcastId: String) -> [Episode] {
    serialQueue.sync {
      fetchEpisodesUnlocked(forPodcastId: podcastId)
    }
  }

  private func fetchAllEpisodesUnlocked() -> [Episode] {
    let descriptor = FetchDescriptor<EpisodeEntity>()
    do {
      let entities = try modelContext.fetch(descriptor)
      return entities.map { $0.toDomainSafe() }
    } catch {
      logger.error("Failed to fetch all episodes: \(error.localizedDescription, privacy: .public)")
      return []
    }
  }

  private func fetchEpisodesUnlocked(forPodcastId podcastId: String) -> [Episode] {
    let predicate = #Predicate<EpisodeEntity> { $0.podcastId == podcastId }
    let descriptor = FetchDescriptor(predicate: predicate)
    do {
      let entities = try modelContext.fetch(descriptor)
      return entities.map { $0.toDomainSafe() }
    } catch {
      logger.error("Failed to fetch episodes for podcast \(podcastId, privacy: .public): \(error.localizedDescription, privacy: .public)")
      return []
    }
  }
}

import Foundation
import CoreModels
import Persistence

public protocol PlaybackConfigurationServicing: Sendable {
  func load() async -> PlaybackSettings
  func save(_ settings: PlaybackSettings) async
  nonisolated func updatesStream() -> AsyncStream<PlaybackSettings>
}

public actor PlaybackConfigurationService: PlaybackConfigurationServicing {
  private let repository: SettingsRepository
  private var continuations: [UUID: AsyncStream<PlaybackSettings>.Continuation] = [:]

  public init(repository: SettingsRepository) {
    self.repository = repository
  }

  public func load() async -> PlaybackSettings {
    await repository.loadGlobalPlaybackSettings()
  }

  public func save(_ settings: PlaybackSettings) async {
    await repository.saveGlobalPlaybackSettings(settings)
    broadcast(settings)
  }

  public nonisolated func updatesStream() -> AsyncStream<PlaybackSettings> {
    AsyncStream { continuation in
      let id = UUID()
      Task { await self.registerContinuation(continuation, id: id) }
    }
  }

  private func broadcast(_ settings: PlaybackSettings) {
    for continuation in continuations.values {
      continuation.yield(settings)
    }
  }

  private func registerContinuation(
    _ continuation: AsyncStream<PlaybackSettings>.Continuation,
    id: UUID
  ) {
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeContinuation(with: id) }
    }
    continuations[id] = continuation
  }

  private func removeContinuation(with id: UUID) {
    continuations[id] = nil
  }
}

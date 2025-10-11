import Foundation
import CoreModels
import Persistence

public protocol DownloadConfigurationServicing: Sendable {
  func load() async -> DownloadSettings
  func save(_ settings: DownloadSettings) async
  nonisolated func updatesStream() -> AsyncStream<DownloadSettings>
}

public actor DownloadConfigurationService: DownloadConfigurationServicing {
  private let repository: SettingsRepository
  private var continuations: [UUID: AsyncStream<DownloadSettings>.Continuation] = [:]

  public init(repository: SettingsRepository) {
    self.repository = repository
  }

  public func load() async -> DownloadSettings {
    await repository.loadGlobalDownloadSettings()
  }

  public func save(_ settings: DownloadSettings) async {
    await repository.saveGlobalDownloadSettings(settings)
    broadcast(settings)
  }

  public nonisolated func updatesStream() -> AsyncStream<DownloadSettings> {
    AsyncStream { continuation in
      let id = UUID()
      Task { await self.registerContinuation(continuation, id: id) }
    }
  }

  private func broadcast(_ settings: DownloadSettings) {
    for continuation in continuations.values {
      continuation.yield(settings)
    }
  }

  private func registerContinuation(
    _ continuation: AsyncStream<DownloadSettings>.Continuation,
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

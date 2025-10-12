import Foundation
import CoreModels
import Persistence

public protocol AppearanceConfigurationServicing: Sendable {
  func load() async -> AppearanceSettings
  func save(_ settings: AppearanceSettings) async
  nonisolated func updatesStream() -> AsyncStream<AppearanceSettings>
}

public actor AppearanceConfigurationService: AppearanceConfigurationServicing {
  private let repository: SettingsRepository
  private var continuations: [UUID: AsyncStream<AppearanceSettings>.Continuation] = [:]

  public init(repository: SettingsRepository) {
    self.repository = repository
  }

  public func load() async -> AppearanceSettings {
    await repository.loadGlobalAppearanceSettings()
  }

  public func save(_ settings: AppearanceSettings) async {
    await repository.saveGlobalAppearanceSettings(settings)
    broadcast(settings)
  }

  public nonisolated func updatesStream() -> AsyncStream<AppearanceSettings> {
    AsyncStream { continuation in
      let id = UUID()
      Task { await registerContinuation(continuation, id: id) }
    }
  }

  private func broadcast(_ settings: AppearanceSettings) {
    for continuation in continuations.values {
      continuation.yield(settings)
    }
  }

  private func registerContinuation(
    _ continuation: AsyncStream<AppearanceSettings>.Continuation,
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


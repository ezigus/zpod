import Foundation
import CoreModels
import Persistence

public protocol SmartListAutomationConfigurationServicing: Sendable {
  func load() async -> SmartListRefreshConfiguration
  func save(_ settings: SmartListRefreshConfiguration) async
  nonisolated func updatesStream() -> AsyncStream<SmartListRefreshConfiguration>
}

public actor SmartListAutomationConfigurationService: SmartListAutomationConfigurationServicing {
  private let repository: SettingsRepository
  private weak var backgroundManager: (any SmartListBackgroundManager & AnyObject)?
  private var continuations: [UUID: AsyncStream<SmartListRefreshConfiguration>.Continuation] = [:]

  public init(
    repository: SettingsRepository,
    backgroundManager: (any SmartListBackgroundManager & AnyObject)? = nil
  ) {
    self.repository = repository
    self.backgroundManager = backgroundManager
  }

  public func load() async -> SmartListRefreshConfiguration {
    await repository.loadSmartListAutomationSettings()
  }

  public func save(_ settings: SmartListRefreshConfiguration) async {
    await repository.saveSmartListAutomationSettings(settings)
    if let backgroundManager {
      await backgroundManager.updateConfiguration(settings)
    }
    broadcast(settings)
  }

  public nonisolated func updatesStream() -> AsyncStream<SmartListRefreshConfiguration> {
    AsyncStream { continuation in
      let id = UUID()
      Task { await registerContinuation(continuation, id: id) }
    }
  }

  private func broadcast(_ settings: SmartListRefreshConfiguration) {
    for continuation in continuations.values {
      continuation.yield(settings)
    }
  }

  private func registerContinuation(
    _ continuation: AsyncStream<SmartListRefreshConfiguration>.Continuation,
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

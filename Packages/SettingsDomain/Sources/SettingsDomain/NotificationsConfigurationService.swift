import Foundation
import CoreModels
import Persistence

public protocol NotificationsConfigurationServicing: Sendable {
  func load() async -> NotificationSettings
  func save(_ settings: NotificationSettings) async
  nonisolated func updatesStream() -> AsyncStream<NotificationSettings>
}

public actor NotificationsConfigurationService: NotificationsConfigurationServicing {
  private let repository: SettingsRepository
  private var continuations: [UUID: AsyncStream<NotificationSettings>.Continuation] = [:]

  public init(repository: SettingsRepository) {
    self.repository = repository
  }

  public func load() async -> NotificationSettings {
    await repository.loadGlobalNotificationSettings()
  }

  public func save(_ settings: NotificationSettings) async {
    await repository.saveGlobalNotificationSettings(settings)
    broadcast(settings)
  }

  public nonisolated func updatesStream() -> AsyncStream<NotificationSettings> {
    AsyncStream { continuation in
      let id = UUID()
      Task { await registerContinuation(continuation, id: id) }
    }
  }

  private func broadcast(_ settings: NotificationSettings) {
    for continuation in continuations.values {
      continuation.yield(settings)
    }
  }

  private func registerContinuation(
    _ continuation: AsyncStream<NotificationSettings>.Continuation,
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


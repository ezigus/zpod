import Foundation
import CoreModels
import Persistence

public struct SwipeConfiguration: Equatable, Sendable {
  public var swipeActions: SwipeActionSettings
  public var hapticStyle: SwipeHapticStyle

  public init(
    swipeActions: SwipeActionSettings,
    hapticStyle: SwipeHapticStyle
  ) {
    self.swipeActions = swipeActions
    self.hapticStyle = hapticStyle
  }

  public static let `default` = SwipeConfiguration(
    swipeActions: .default,
    hapticStyle: .medium
  )
}

public protocol SwipeConfigurationServicing: Sendable {
  func load() async -> SwipeConfiguration
  func save(_ configuration: SwipeConfiguration) async throws
  nonisolated func updatesStream() -> AsyncStream<SwipeConfiguration>
}

public actor SwipeConfigurationService: SwipeConfigurationServicing {
  private let repository: SettingsRepository
  private var continuations: [UUID: AsyncStream<SwipeConfiguration>.Continuation] = [:]

  public init(repository: SettingsRepository) {
    self.repository = repository
  }

  public func load() async -> SwipeConfiguration {
    let settings = await repository.loadGlobalUISettings()
    return SwipeConfiguration(swipeActions: settings.swipeActions, hapticStyle: settings.hapticStyle)
  }

  public func save(_ configuration: SwipeConfiguration) async throws {
    let uiSettings = UISettings(
      swipeActions: configuration.swipeActions,
      hapticStyle: configuration.hapticStyle
    )
    await repository.saveGlobalUISettings(uiSettings)
    broadcast(configuration)
  }

  public nonisolated func updatesStream() -> AsyncStream<SwipeConfiguration> {
    AsyncStream { continuation in
      let id = UUID()
      Task { await registerContinuation(continuation, id: id) }
    }
  }

  private func broadcast(_ configuration: SwipeConfiguration) {
    for continuation in continuations.values {
      continuation.yield(configuration)
    }
  }

  private func registerContinuation(
    _ continuation: AsyncStream<SwipeConfiguration>.Continuation,
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

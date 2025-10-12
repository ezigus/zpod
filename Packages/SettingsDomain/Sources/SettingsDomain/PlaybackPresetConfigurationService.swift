import Foundation
import CoreModels
import Persistence

public protocol PlaybackPresetConfigurationServicing: Sendable {
  func loadLibrary() async -> PlaybackPresetLibrary
  func saveLibrary(_ library: PlaybackPresetLibrary) async
  nonisolated func updatesStream() -> AsyncStream<PlaybackPresetLibrary>
}

public actor PlaybackPresetConfigurationService: PlaybackPresetConfigurationServicing {
  private let repository: SettingsRepository
  private var continuations: [UUID: AsyncStream<PlaybackPresetLibrary>.Continuation] = [:]

  public init(repository: SettingsRepository) {
    self.repository = repository
  }

  public func loadLibrary() async -> PlaybackPresetLibrary {
    await repository.loadPlaybackPresetLibrary()
  }

  public func saveLibrary(_ library: PlaybackPresetLibrary) async {
    await repository.savePlaybackPresetLibrary(library)
    broadcast(library)
  }

  public nonisolated func updatesStream() -> AsyncStream<PlaybackPresetLibrary> {
    AsyncStream { continuation in
      let id = UUID()
      Task { await registerContinuation(continuation, id: id) }
    }
  }

  private func broadcast(_ library: PlaybackPresetLibrary) {
    for continuation in continuations.values {
      continuation.yield(library)
    }
  }

  private func registerContinuation(
    _ continuation: AsyncStream<PlaybackPresetLibrary>.Continuation,
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


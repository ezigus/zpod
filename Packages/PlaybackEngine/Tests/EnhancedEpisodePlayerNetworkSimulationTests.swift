import XCTest
#if canImport(Combine)
@preconcurrency import CombineSupport
import Combine
#endif
@testable import PlaybackEngine
import CoreModels

@MainActor
final class EnhancedEpisodePlayerNetworkSimulationTests: XCTestCase {
  nonisolated(unsafe) private var player: EnhancedEpisodePlayer!
  nonisolated(unsafe) private var ticker: DeterministicTicker!
  nonisolated(unsafe) private var cancellables: Set<AnyCancellable>!

  override nonisolated func setUp() async throws {
    try await super.setUp()
    ticker = DeterministicTicker()
    player = await EnhancedEpisodePlayer(
      ticker: ticker,
      simulationRecoveryGracePeriod: 0.05
    )
    cancellables = []
  }

  override nonisolated func tearDown() async throws {
    cancellables = nil
    player = nil
    ticker = nil
    try await super.tearDown()
  }

  func testSimulatedNetworkLossPausesPlaybackAndPublishesPausedState() async throws {
    let episode = Episode(id: "sim-loss-1", title: "Network Loss", duration: 120)
    var pausedStates: [Bool] = []

    player.networkSimulationPausedPublisher
      .sink { pausedStates.append($0) }
      .store(in: &cancellables)

    player.play(episode: episode, duration: 120)
    await ticker.tick(count: 1)

    player.simulateNetworkLoss()

    XCTAssertFalse(player.isPlaying, "Player should pause when simulated network loss occurs")
    XCTAssertEqual(pausedStates.last, true, "Paused simulation publisher should emit true")
  }

  func testSimulatedRecoveryResumesAfterGracePeriod() async throws {
    let episode = Episode(id: "sim-recovery-1", title: "Recovery", duration: 120)
    var pausedStates: [Bool] = []

    player.networkSimulationPausedPublisher
      .sink { pausedStates.append($0) }
      .store(in: &cancellables)

    player.play(episode: episode, duration: 120)
    await ticker.tick(count: 1)
    player.simulateNetworkLoss()
    XCTAssertFalse(player.isPlaying)

    player.simulateNetworkRecovery()
    try await Task.sleep(for: .milliseconds(120))

    XCTAssertTrue(player.isPlaying, "Player should resume after simulated recovery grace period")
    XCTAssertEqual(pausedStates.last, false, "Paused simulation publisher should emit false after recovery")
  }

  func testSimulatedRecoveryCancelsWhenNetworkLossOccursAgain() async throws {
    let episode = Episode(id: "sim-recovery-cancel-1", title: "Recovery Cancel", duration: 120)

    player.play(episode: episode, duration: 120)
    await ticker.tick(count: 1)

    player.simulateNetworkLoss()
    XCTAssertFalse(player.isPlaying)

    player.simulateNetworkRecovery()
    try await Task.sleep(for: .milliseconds(10))
    player.simulateNetworkLoss()

    try await Task.sleep(for: .milliseconds(120))
    XCTAssertFalse(player.isPlaying, "Player should remain paused when recovery is cancelled by a second loss")
  }

  func testBufferSimulationPublishesExpectedStates() async {
    var bufferStates: [Bool] = []

    player.bufferSimulationPublisher
      .sink { bufferStates.append($0) }
      .store(in: &cancellables)

    player.simulateBufferEmpty()
    XCTAssertEqual(bufferStates.last, true, "Buffer empty should publish true")

    player.simulateBufferReady()
    XCTAssertEqual(bufferStates.last, false, "Buffer ready should publish false")

    player.simulatePoorNetwork()
    XCTAssertEqual(bufferStates.last, true, "Poor network should publish buffering=true")
  }
}

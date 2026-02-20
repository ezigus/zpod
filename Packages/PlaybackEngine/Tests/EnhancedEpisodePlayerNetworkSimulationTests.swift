import XCTest
#if canImport(Combine)
@preconcurrency import CombineSupport
import Combine
#endif
@testable import PlaybackEngine
import CoreModels
import SharedUtilities

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
    // Grace period is 50ms; wait 300ms (6x) to give the MainActor-bound
    // recovery task time to schedule on slow CI runners.
    try await Task.sleep(for: .milliseconds(300))

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

  func testSimulatedPlaybackErrorPublishesRecoverableFailedState() async throws {
    let episode = Episode(id: "sim-error-1", title: "Recoverable Error", duration: 120)
    var observedStates: [EpisodePlaybackState] = []

    player.statePublisher
      .sink { observedStates.append($0) }
      .store(in: &cancellables)

    player.play(episode: episode, duration: 120)
    await ticker.tick(count: 1)

    player.simulatePlaybackError()

    guard let latestState = observedStates.last else {
      XCTFail("Expected playback state after simulated playback error")
      return
    }

    guard case .failed(_, _, _, let error) = latestState else {
      XCTFail("Expected failed playback state after simulated playback error")
      return
    }

    XCTAssertEqual(error, .networkError, "Simulated playback error should use recoverable networkError")
    XCTAssertTrue(error.isRecoverable, "Simulated playback error must be recoverable for retry assertions")
    XCTAssertFalse(player.isPlaying, "Player should stop playing when simulated playback error occurs")
  }

  func testSimulatedNetworkTypeChangeKeepsPlaybackRunning() async throws {
    let episode = Episode(id: "sim-network-type-1", title: "Network Type", duration: 240)
    var bufferStates: [Bool] = []

    player.bufferSimulationPublisher
      .sink { bufferStates.append($0) }
      .store(in: &cancellables)

    player.play(episode: episode, duration: 240)
    await ticker.tick(count: 1)
    XCTAssertTrue(player.isPlaying)

    player.simulateNetworkTypeChange()
    XCTAssertTrue(player.isPlaying, "Network type transitions should not pause playback")
    XCTAssertEqual(bufferStates.last, true, "Network type transition should briefly surface buffering")

    try await Task.sleep(for: .milliseconds(950))
    XCTAssertEqual(bufferStates.last, false, "Buffering should clear after transition stabilization")
  }

  func testSimulatedPlaybackErrorTypeMappings() async throws {
    let episode = Episode(id: "sim-error-map-1", title: "Error Mapping", duration: 180)
    var lastError: PlaybackError?

    player.statePublisher
      .sink { state in
        guard case .failed(_, _, _, let error) = state else { return }
        lastError = error
      }
      .store(in: &cancellables)

    player.play(episode: episode, duration: 180)
    await ticker.tick(count: 1)

    player.simulatePlaybackError(.serverError)
    XCTAssertEqual(lastError, .networkError)

    player.play(episode: episode, duration: 180)
    await ticker.tick(count: 1)
    player.simulatePlaybackError(.notFound)
    XCTAssertEqual(lastError, .episodeUnavailable)

    player.play(episode: episode, duration: 180)
    await ticker.tick(count: 1)
    player.simulatePlaybackError(.timeout)
    XCTAssertEqual(lastError, .timeout)
  }
}

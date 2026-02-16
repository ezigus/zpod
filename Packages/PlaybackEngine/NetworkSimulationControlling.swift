import Foundation
#if canImport(Combine)
@preconcurrency import CombineSupport
#endif
import SharedUtilities

/// Simulation controls used by UI tests to inject network and buffering events.
@MainActor
public protocol NetworkSimulationControlling: AnyObject {
  #if canImport(Combine)
  var networkSimulationPausedPublisher: AnyPublisher<Bool, Never> { get }
  var bufferSimulationPublisher: AnyPublisher<Bool, Never> { get }
  #endif

  func simulateNetworkLoss()
  func simulateNetworkRecovery()
  func simulatePoorNetwork()
  func simulateNetworkTypeChange()
  func simulateBufferEmpty()
  func simulateBufferReady()
  func simulateSeekWithinBuffer()
  func simulateSeekOutsideBuffer()
  func simulatePlaybackError()
  func simulatePlaybackError(_ type: PlaybackErrorSimulationType)
}

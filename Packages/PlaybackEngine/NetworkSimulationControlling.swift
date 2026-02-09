import Foundation
#if canImport(Combine)
@preconcurrency import CombineSupport
#endif

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
  func simulateBufferEmpty()
  func simulateBufferReady()
}

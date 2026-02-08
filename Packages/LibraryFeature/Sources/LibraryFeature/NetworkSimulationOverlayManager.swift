#if os(iOS)
  import Foundation
  import PlaybackEngine
  import SharedUtilities

  /// Owns network/buffer simulation observer lifecycle for UI test runs.
  /// This manager does not render UI; it bridges `TestHook` notifications to
  /// the shared playback service when simulation env flags are enabled.
  @MainActor
  public final class NetworkSimulationOverlayManager {
    public static let shared = NetworkSimulationOverlayManager()

    nonisolated(unsafe) private var appInitObserver: NSObjectProtocol?
    nonisolated(unsafe) private var networkSimulationObserver: NSObjectProtocol?
    nonisolated(unsafe) private var bufferSimulationObserver: NSObjectProtocol?
    private weak var simulationController: (any NetworkSimulationControlling)?

    private init() {
      guard isNetworkSimulationEnabled || isBufferSimulationEnabled else { return }

      appInitObserver = NotificationCenter.default.addObserver(
        forName: .appDidInitialize,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.activateIfNeeded()
        }
      }
    }

    deinit {
      if let networkSimulationObserver {
        NotificationCenter.default.removeObserver(networkSimulationObserver)
      }
      if let bufferSimulationObserver {
        NotificationCenter.default.removeObserver(bufferSimulationObserver)
      }
      if let appInitObserver {
        NotificationCenter.default.removeObserver(appInitObserver)
      }
      networkSimulationObserver = nil
      bufferSimulationObserver = nil
      appInitObserver = nil
    }

    private var isNetworkSimulationEnabled: Bool {
      ProcessInfo.processInfo.environment["UITEST_NETWORK_SIMULATION"] == "1"
    }

    private var isBufferSimulationEnabled: Bool {
      ProcessInfo.processInfo.environment["UITEST_BUFFER_SIMULATION"] == "1"
    }

    private func activateIfNeeded() {
      if simulationController == nil {
        simulationController = PlaybackEnvironment.playbackService as? any NetworkSimulationControlling
      }

      guard let controller = simulationController else { return }

      if isNetworkSimulationEnabled && networkSimulationObserver == nil {
        networkSimulationObserver = NotificationCenter.default.addObserver(
          forName: .networkSimulation,
          object: nil,
          queue: .main
        ) { [weak self] notification in
          guard
            let rawType = notification.userInfo?[NetworkSimulationNotificationKey.networkType] as? String,
            let type = NetworkSimulationType(rawValue: rawType)
          else {
            return
          }
          MainActor.assumeIsolated {
            self?.handleNetworkSimulation(type, controller: controller)
          }
        }
      }

      if isBufferSimulationEnabled && bufferSimulationObserver == nil {
        bufferSimulationObserver = NotificationCenter.default.addObserver(
          forName: .bufferSimulation,
          object: nil,
          queue: .main
        ) { [weak self] notification in
          guard
            let rawType = notification.userInfo?[NetworkSimulationNotificationKey.bufferType] as? String,
            let type = BufferSimulationType(rawValue: rawType)
          else {
            return
          }
          MainActor.assumeIsolated {
            self?.handleBufferSimulation(type, controller: controller)
          }
        }
      }
    }

    private func handleNetworkSimulation(
      _ type: NetworkSimulationType,
      controller: any NetworkSimulationControlling
    ) {
      switch type {
      case .loss:
        controller.simulateNetworkLoss()
      case .recovery:
        controller.simulateNetworkRecovery()
      case .poorQuality:
        controller.simulatePoorNetwork()
      }
    }

    private func handleBufferSimulation(
      _ type: BufferSimulationType,
      controller: any NetworkSimulationControlling
    ) {
      switch type {
      case .empty:
        controller.simulateBufferEmpty()
      case .ready:
        controller.simulateBufferReady()
      }
    }
  }
#endif

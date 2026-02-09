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
    nonisolated(unsafe) private var playbackErrorSimulationObserver: NSObjectProtocol?
    private weak var simulationController: (any NetworkSimulationControlling)?

    private init() {
      guard isNetworkSimulationEnabled || isBufferSimulationEnabled || isPlaybackErrorSimulationEnabled
      else { return }

      appInitObserver = NotificationCenter.default.addObserver(
        forName: .appDidInitialize,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
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
      if let playbackErrorSimulationObserver {
        NotificationCenter.default.removeObserver(playbackErrorSimulationObserver)
      }
      if let appInitObserver {
        NotificationCenter.default.removeObserver(appInitObserver)
      }
      networkSimulationObserver = nil
      bufferSimulationObserver = nil
      playbackErrorSimulationObserver = nil
      appInitObserver = nil
    }

    private var isNetworkSimulationEnabled: Bool {
      ProcessInfo.processInfo.environment["UITEST_NETWORK_SIMULATION"] == "1"
    }

    private var isBufferSimulationEnabled: Bool {
      ProcessInfo.processInfo.environment["UITEST_BUFFER_SIMULATION"] == "1"
    }

    private var isPlaybackErrorSimulationEnabled: Bool {
      ProcessInfo.processInfo.environment["UITEST_PLAYBACK_ERROR_SIMULATION"] == "1"
    }

    private func activateIfNeeded() {
      _ = currentSimulationController()

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
          Task { @MainActor [weak self] in
            self?.handleNetworkSimulation(type)
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
          Task { @MainActor [weak self] in
            self?.handleBufferSimulation(type)
          }
        }
      }

      if isPlaybackErrorSimulationEnabled && playbackErrorSimulationObserver == nil {
        playbackErrorSimulationObserver = NotificationCenter.default.addObserver(
          forName: .playbackErrorSimulation,
          object: nil,
          queue: .main
        ) { [weak self] notification in
          guard
            let rawType = notification.userInfo?[NetworkSimulationNotificationKey.playbackErrorType]
              as? String,
            let type = PlaybackErrorSimulationType(rawValue: rawType)
          else {
            return
          }
          Task { @MainActor [weak self] in
            self?.handlePlaybackErrorSimulation(type)
          }
        }
      }
    }

    private func currentSimulationController() -> (any NetworkSimulationControlling)? {
      if let simulationController {
        return simulationController
      }

      let controller = PlaybackEnvironment.playbackService as? any NetworkSimulationControlling
      simulationController = controller
      return controller
    }

    private func handleNetworkSimulation(_ type: NetworkSimulationType) {
      guard let controller = currentSimulationController() else { return }
      switch type {
      case .loss:
        controller.simulateNetworkLoss()
      case .recovery:
        controller.simulateNetworkRecovery()
      case .poorQuality:
        controller.simulatePoorNetwork()
      }
    }

    private func handleBufferSimulation(_ type: BufferSimulationType) {
      guard let controller = currentSimulationController() else { return }
      switch type {
      case .empty:
        controller.simulateBufferEmpty()
      case .ready:
        controller.simulateBufferReady()
      }
    }

    private func handlePlaybackErrorSimulation(_ type: PlaybackErrorSimulationType) {
      guard let controller = currentSimulationController() else { return }
      switch type {
      case .recoverableNetworkError:
        controller.simulatePlaybackError()
      }
    }
  }
#endif

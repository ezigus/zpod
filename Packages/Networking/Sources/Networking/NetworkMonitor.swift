import CombineSupport
import Foundation
import Network
import OSLog

/// Network connection status
public enum NetworkStatus: Sendable, Equatable {
    case connected
    case disconnected
    case unknown

    public var isConnected: Bool {
        self == .connected
    }
}

/// Network connection quality
public enum NetworkQuality: Sendable, Equatable {
    case excellent  // WiFi or 5G
    case good       // 4G/LTE
    case poor       // 3G or worse
    case unknown
}

/// Monitors network reachability and publishes status changes
///
/// **Purpose**: Detect when network goes offline/online to enable smart playback behavior
/// like auto-pause on network loss and auto-resume on recovery.
///
/// **Architecture**:
/// - Uses `NWPathMonitor` for native iOS reachability detection
/// - Publishes status changes via Combine
/// - Thread-safe with proper dispatch queue isolation
///
/// **Usage**:
/// ```swift
/// let monitor = NetworkMonitor()
/// monitor.start()
///
/// monitor.statusPublisher
///     .sink { status in
///         if status == .disconnected {
///             // Pause playback
///         }
///     }
///     .store(in: &cancellables)
/// ```
///
/// **Issue**: #28.1.4 - Network Monitoring and Adaptation
@available(iOS 12.0, macOS 10.14, *)
public final class NetworkMonitor: @unchecked Sendable {

    // MARK: - Public Properties

    /// Current network status
    public var currentStatus: NetworkStatus {
        subjectQueue.sync { statusSubject.value }
    }

    /// Current network quality (bandwidth estimation)
    public var currentQuality: NetworkQuality {
        subjectQueue.sync { qualitySubject.value }
    }

    /// Publisher for network status changes
    public var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    /// Publisher for network quality changes
    public var qualityPublisher: AnyPublisher<NetworkQuality, Never> {
        qualitySubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private let pathMonitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    private let subjectQueue = DispatchQueue(label: "us.zig.zpod.networkmonitor.subjects")
    private let statusSubject = CurrentValueSubject<NetworkStatus, Never>(.unknown)
    private let qualitySubject = CurrentValueSubject<NetworkQuality, Never>(.unknown)

    private static let logger = Logger(
        subsystem: "us.zig.zpod",
        category: "NetworkMonitor"
    )

    // MARK: - Initialization

    public init() {
        self.pathMonitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(
            label: "us.zig.zpod.networkmonitor",
            qos: .utility
        )

        setupPathUpdateHandler()
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Start monitoring network reachability
    public func start() {
        Self.logger.info("Starting network monitoring")
        pathMonitor.start(queue: monitorQueue)
    }

    /// Stop monitoring network reachability
    public func stop() {
        Self.logger.info("Stopping network monitoring")
        pathMonitor.cancel()
    }

    // MARK: - Private Methods

    private func setupPathUpdateHandler() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let newStatus: NetworkStatus
            let newQuality: NetworkQuality

            switch path.status {
            case .satisfied:
                newStatus = .connected
                newQuality = self.estimateQuality(from: path)

                Self.logger.info("Network connected - Quality: \(String(describing: newQuality))")

            case .unsatisfied:
                newStatus = .disconnected
                newQuality = .unknown

                Self.logger.warning("Network disconnected")

            case .requiresConnection:
                newStatus = .disconnected
                newQuality = .unknown

                Self.logger.warning("Network requires connection")

            @unknown default:
                newStatus = .unknown
                newQuality = .unknown

                Self.logger.warning("Network status unknown")
            }

            // Update status if changed (using subject queue for thread safety)
            self.subjectQueue.async {
                let oldStatus = self.statusSubject.value
                if newStatus != oldStatus {
                    self.statusSubject.send(newStatus)
                }

                // Update quality if changed
                let oldQuality = self.qualitySubject.value
                if newQuality != oldQuality {
                    self.qualitySubject.send(newQuality)
                }
            }
        }
    }

    /// Estimate network quality based on path characteristics
    private func estimateQuality(from path: NWPath) -> NetworkQuality {
        // Check if using expensive interface (cellular)
        if path.isExpensive {
            // Cellular connection - estimate based on interface type
            if path.usesInterfaceType(.cellular) {
                // Modern cellular is usually good quality
                // (In a production app, we might check NWPath.effectiveConnectionType
                // if available in future iOS versions)
                return .good
            }
            return .poor
        }

        // WiFi or wired connection
        if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) {
            return .excellent
        }

        // Other connection types
        if path.usesInterfaceType(.loopback) {
            return .excellent
        }

        return .unknown
    }
}

// MARK: - Convenience Extensions

@available(iOS 12.0, macOS 10.14, *)
extension NetworkMonitor {

    /// Check if currently connected to network
    public var isConnected: Bool {
        currentStatus.isConnected
    }

    /// Check if network quality is good enough for streaming
    public var canStream: Bool {
        guard isConnected else { return false }

        switch currentQuality {
        case .excellent, .good:
            return true
        case .poor, .unknown:
            // Allow streaming on poor/unknown, but app should handle buffering
            return true
        }
    }
}

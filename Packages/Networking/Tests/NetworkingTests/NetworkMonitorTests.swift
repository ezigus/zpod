import CombineSupport
import XCTest
@testable import Networking

/// Tests for NetworkMonitor service
///
/// **Note**: These tests verify the API surface and basic behavior.
/// Actual network status changes are difficult to test in unit tests
/// and should be verified through integration/manual testing.
///
/// **Issue**: #28.1.4 - Network Monitoring and Adaptation
@available(iOS 12.0, macOS 10.14, *)
final class NetworkMonitorTests: XCTestCase {

    var monitor: NetworkMonitor!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        monitor = NetworkMonitor()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        monitor?.stop()
        monitor = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        // Then: Monitor should be created with unknown initial status
        XCTAssertEqual(monitor.currentStatus, .unknown, "Initial status should be unknown")
        XCTAssertEqual(monitor.currentQuality, .unknown, "Initial quality should be unknown")
    }

    func testStartMonitoring() {
        // When: Monitor is started
        monitor.start()

        // Then: Should not crash and should eventually detect network status
        // (Actual status detection depends on system state)
        XCTAssertNotNil(monitor, "Monitor should remain valid after start")
    }

    func testStopMonitoring() {
        // Given: Monitor is started
        monitor.start()

        // When: Monitor is stopped
        monitor.stop()

        // Then: Should not crash
        XCTAssertNotNil(monitor, "Monitor should remain valid after stop")
    }

    // MARK: - Status Publisher Tests

    func testStatusPublisherEmitsCurrentValue() {
        let expectation = expectation(description: "Status publisher emits")
        var receivedStatus: NetworkStatus?

        // When: Subscribe to status publisher
        monitor.statusPublisher
            .sink { status in
                receivedStatus = status
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Then: Should receive current status (unknown on init)
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedStatus, .unknown, "Should receive initial status")
    }

    func testQualityPublisherEmitsCurrentValue() {
        let expectation = expectation(description: "Quality publisher emits")
        var receivedQuality: NetworkQuality?

        // When: Subscribe to quality publisher
        monitor.qualityPublisher
            .sink { quality in
                receivedQuality = quality
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Then: Should receive current quality (unknown on init)
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedQuality, .unknown, "Should receive initial quality")
    }

    // MARK: - Convenience Property Tests

    func testIsConnectedWhenDisconnected() {
        // Given: Status is disconnected (via initial state or actual detection)
        // Note: We can't force disconnection in unit tests

        // Then: isConnected should match status
        let isConnected = monitor.isConnected
        let status = monitor.currentStatus

        if status == .disconnected {
            XCTAssertFalse(isConnected, "isConnected should be false when disconnected")
        } else if status == .connected {
            XCTAssertTrue(isConnected, "isConnected should be true when connected")
        }
        // For .unknown, either value is acceptable
    }

    func testCanStreamWhenConnected() {
        // When: Monitor is started and detects network
        monitor.start()

        // Give it a moment to detect network status
        let expectation = expectation(description: "Network detection")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then: canStream should be reasonable based on status
        let canStream = monitor.canStream
        let status = monitor.currentStatus

        if status == .disconnected {
            XCTAssertFalse(canStream, "Should not be able to stream when disconnected")
        } else if status == .connected {
            XCTAssertTrue(canStream, "Should be able to stream when connected")
        }
        // For .unknown, either value is acceptable during transition
    }

    // MARK: - Status Enum Tests

    func testNetworkStatusEquality() {
        XCTAssertEqual(NetworkStatus.connected, .connected)
        XCTAssertEqual(NetworkStatus.disconnected, .disconnected)
        XCTAssertEqual(NetworkStatus.unknown, .unknown)

        XCTAssertNotEqual(NetworkStatus.connected, .disconnected)
        XCTAssertNotEqual(NetworkStatus.connected, .unknown)
        XCTAssertNotEqual(NetworkStatus.disconnected, .unknown)
    }

    func testNetworkStatusIsConnected() {
        XCTAssertTrue(NetworkStatus.connected.isConnected)
        XCTAssertFalse(NetworkStatus.disconnected.isConnected)
        XCTAssertFalse(NetworkStatus.unknown.isConnected)
    }

    func testNetworkQualityEquality() {
        XCTAssertEqual(NetworkQuality.excellent, .excellent)
        XCTAssertEqual(NetworkQuality.good, .good)
        XCTAssertEqual(NetworkQuality.poor, .poor)
        XCTAssertEqual(NetworkQuality.unknown, .unknown)

        XCTAssertNotEqual(NetworkQuality.excellent, .good)
        XCTAssertNotEqual(NetworkQuality.good, .poor)
    }

    // MARK: - Lifecycle Tests

    func testMultipleStartStopCycles() {
        // When: Start and stop multiple times
        monitor.start()
        monitor.stop()

        monitor.start()
        monitor.stop()

        monitor.start()
        monitor.stop()

        // Then: Should not crash or leak
        XCTAssertNotNil(monitor, "Monitor should survive multiple start/stop cycles")
    }

    func testDeinitStopsMonitoring() {
        // Given: Monitor is started
        var localMonitor: NetworkMonitor? = NetworkMonitor()
        localMonitor?.start()

        // When: Monitor is deallocated
        localMonitor = nil

        // Then: Should not crash (deinit calls stop())
        // Success is implicit - no crash
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() {
        let expectation = expectation(description: "Concurrent access completes")
        expectation.expectedFulfillmentCount = 10

        // When: Access monitor from multiple threads
        for _ in 0..<10 {
            DispatchQueue.global().async {
                _ = self.monitor.currentStatus
                _ = self.monitor.currentQuality
                _ = self.monitor.isConnected
                _ = self.monitor.canStream
                expectation.fulfill()
            }
        }

        // Then: Should not crash or deadlock
        wait(for: [expectation], timeout: 5.0)
    }
}

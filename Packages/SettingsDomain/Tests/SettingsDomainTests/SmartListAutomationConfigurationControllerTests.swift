import XCTest
import CoreModels
@testable import SettingsDomain

@MainActor
final class SmartListAutomationConfigurationControllerTests: XCTestCase {
  private var service: InMemorySmartListAutomationService!
  private var controller: SmartListAutomationConfigurationController!

  override func setUp() async throws {
    service = InMemorySmartListAutomationService(initial: SmartListRefreshConfiguration())
    controller = SmartListAutomationConfigurationController(service: service)
  }

  override func tearDown() async throws {
    controller = nil
    service = nil
  }

  func testLoadBaselineAppliesConfiguration() async {
    await controller.loadBaseline()
    XCTAssertFalse(controller.hasUnsavedChanges)
    XCTAssertTrue(controller.isEnabled)
    XCTAssertEqual(controller.globalInterval, 300, accuracy: 0.001)
  }

  func testSettingIntervalClampsWithinBounds() async {
    await controller.loadBaseline()
    controller.setGlobalInterval(30) // below minimum
    XCTAssertEqual(controller.globalInterval, 60, accuracy: 0.001)

    controller.setGlobalInterval(100_000)
    XCTAssertEqual(controller.globalInterval, 14_400, accuracy: 0.001)
  }

  func testCommitChangesPersistsConfiguration() async {
    await controller.loadBaseline()
    controller.setEnabled(false)
    controller.setMaxRefreshPerCycle(3)

    await controller.commitChanges()
    XCTAssertFalse(controller.hasUnsavedChanges)

    let stored = await service.load()
    XCTAssertFalse(stored.isEnabled)
    XCTAssertEqual(stored.maxRefreshPerCycle, 3)
  }
}

// MARK: - Test Double

actor InMemorySmartListAutomationService: SmartListAutomationConfigurationServicing {
  private var stored: SmartListRefreshConfiguration
  private var continuation: AsyncStream<SmartListRefreshConfiguration>.Continuation?

  init(initial: SmartListRefreshConfiguration) {
    stored = initial
  }

  func load() async -> SmartListRefreshConfiguration { stored }

  func save(_ settings: SmartListRefreshConfiguration) async {
    stored = settings
    continuation?.yield(settings)
  }

  nonisolated func updatesStream() -> AsyncStream<SmartListRefreshConfiguration> {
    AsyncStream { continuation in
      Task { await self.storeContinuation(continuation) }
    }
  }

  private func storeContinuation(_ continuation: AsyncStream<SmartListRefreshConfiguration>.Continuation) {
    self.continuation = continuation
  }
}


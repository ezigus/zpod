import XCTest
import CoreModels
@testable import SettingsDomain

@MainActor
final class AppearanceConfigurationControllerTests: XCTestCase {
  private var service: InMemoryAppearanceService!
  private var controller: AppearanceConfigurationController!

  override func setUp() async throws {
    service = InMemoryAppearanceService(initial: .default)
    controller = AppearanceConfigurationController(service: service)
  }

  override func tearDown() async throws {
    controller = nil
    service = nil
  }

  func testLoadBaselineAppliesServiceSettings() async {
    await controller.loadBaseline()
    XCTAssertFalse(controller.hasUnsavedChanges)
    XCTAssertEqual(controller.theme, .system)
    XCTAssertEqual(controller.typographyScale, 1.0, accuracy: 0.001)
  }

  func testSettingThemeMarksUnsavedChanges() async {
    await controller.loadBaseline()
    controller.setTheme(.dark)
    XCTAssertTrue(controller.hasUnsavedChanges)
    XCTAssertEqual(controller.theme, .dark)
  }

  func testTypographyScaleClampsToBounds() async {
    await controller.loadBaseline()
    controller.setTypographyScale(5.0)
    XCTAssertEqual(controller.typographyScale, 1.5, accuracy: 0.001)

    controller.setTypographyScale(0.1)
    XCTAssertEqual(controller.typographyScale, 0.8, accuracy: 0.001)
  }

  func testCommitChangesPersistsSettings() async {
    await controller.loadBaseline()
    controller.setPreferredTint(.orange)
    controller.setReduceMotionEnabled(true)

    await controller.commitChanges()
    XCTAssertFalse(controller.hasUnsavedChanges)

    let stored = await service.load()
    XCTAssertEqual(stored.preferredTint, .orange)
    XCTAssertTrue(stored.reduceMotionEnabled)
  }
}

// MARK: - Test Double

actor InMemoryAppearanceService: AppearanceConfigurationServicing {
  private var stored: AppearanceSettings
  private var continuation: AsyncStream<AppearanceSettings>.Continuation?

  init(initial: AppearanceSettings) {
    stored = initial
  }

  func load() async -> AppearanceSettings { stored }

  func save(_ settings: AppearanceSettings) async {
    stored = settings
    continuation?.yield(settings)
  }

  nonisolated func updatesStream() -> AsyncStream<AppearanceSettings> {
    AsyncStream { continuation in
      Task { await self.storeContinuation(continuation) }
    }
  }

  private func storeContinuation(_ continuation: AsyncStream<AppearanceSettings>.Continuation) {
    self.continuation = continuation
  }
}


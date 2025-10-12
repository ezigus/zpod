import XCTest
import CoreModels
@testable import SettingsDomain

@MainActor
final class NotificationsConfigurationControllerTests: XCTestCase {
  private var service: InMemoryNotificationsService!
  private var controller: NotificationsConfigurationController!

  override func setUp() async throws {
    service = InMemoryNotificationsService(initial: .default)
    controller = NotificationsConfigurationController(service: service)
  }

  override func tearDown() async throws {
    controller = nil
    service = nil
  }

  func testLoadBaselineAppliesServiceSettings() async {
    await controller.loadBaseline()
    XCTAssertFalse(controller.hasUnsavedChanges)
    XCTAssertEqual(controller.deliverySchedule, .immediate)
    XCTAssertTrue(controller.newEpisodeNotificationsEnabled)
  }

  func testMutationsSetHasUnsavedChanges() async {
    await controller.loadBaseline()
    controller.setNewEpisodeNotificationsEnabled(false)
    XCTAssertTrue(controller.hasUnsavedChanges)
    XCTAssertFalse(controller.newEpisodeNotificationsEnabled)
  }

  func testQuietHoursRoundTrip() async {
    await controller.loadBaseline()
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.timeZone = .current
    let newStartReference = formatter.date(from: "21:30") ?? Date()
    controller.setQuietHoursEnabled(true)
    controller.setQuietHoursStart(newStartReference)
    controller.setQuietHoursEnd(newStartReference.addingTimeInterval(60 * 60))
    XCTAssertTrue(controller.hasUnsavedChanges)
    XCTAssertEqual(controller.draft.quietHoursStart, "21:30")
  }

  func testCommitChangesPersistsAndResetsUnsavedFlag() async {
    await controller.loadBaseline()
    controller.setDeliverySchedule(.weeklySummary)
    XCTAssertTrue(controller.hasUnsavedChanges)

    await controller.commitChanges()
    XCTAssertFalse(controller.hasUnsavedChanges)

    let stored = await service.load()
    XCTAssertEqual(stored.deliverySchedule, .weeklySummary)
  }
}

// MARK: - Test Double

actor InMemoryNotificationsService: NotificationsConfigurationServicing {
  private var stored: NotificationSettings
  private var continuation: AsyncStream<NotificationSettings>.Continuation?

  init(initial: NotificationSettings) {
    stored = initial
  }

  func load() async -> NotificationSettings { stored }

  func save(_ settings: NotificationSettings) async {
    stored = settings
    continuation?.yield(settings)
  }

  nonisolated func updatesStream() -> AsyncStream<NotificationSettings> {
    AsyncStream { continuation in
      Task { await self.storeContinuation(continuation) }
    }
  }

  private func storeContinuation(_ continuation: AsyncStream<NotificationSettings>.Continuation) {
    self.continuation = continuation
  }
}


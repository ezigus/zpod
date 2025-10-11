import XCTest
import CoreModels
@testable import SettingsDomain

@MainActor
final class DownloadConfigurationControllerTests: XCTestCase {
  func testLoadBaselinePopulatesDraft() async {
    let initial = DownloadSettings(
      autoDownloadEnabled: true,
      wifiOnly: false,
      maxConcurrentDownloads: 4,
      retentionPolicy: .deleteAfterDays(21),
      defaultUpdateFrequency: .daily
    )

    let service = InMemoryDownloadConfigurationService(initial: initial)
    let controller = DownloadConfigurationController(service: service)

    await controller.loadBaseline()

    XCTAssertTrue(controller.autoDownloadEnabled)
    XCTAssertFalse(controller.wifiOnlyEnabled)
    XCTAssertEqual(controller.maxConcurrentDownloads, 4)
    XCTAssertEqual(controller.retentionPolicy, .deleteAfterDays(21))
    XCTAssertEqual(controller.updateFrequency, .daily)
    XCTAssertFalse(controller.hasUnsavedChanges)
  }

  func testMutationsMarkUnsavedAndCommit() async {
    let service = InMemoryDownloadConfigurationService(initial: DownloadSettings.default)
    let controller = DownloadConfigurationController(service: service)
    await controller.loadBaseline()

    controller.setAutoDownloadEnabled(true)
    controller.setMaxConcurrentDownloads(6)
    controller.setRetentionPolicy(.keepLatest(3))

    XCTAssertTrue(controller.hasUnsavedChanges)

    await controller.commitChanges()

    XCTAssertFalse(controller.hasUnsavedChanges)
    let saved = await service.load()
    XCTAssertTrue(saved.autoDownloadEnabled)
    XCTAssertEqual(saved.maxConcurrentDownloads, 6)
    if case .keepLatest(let count) = saved.retentionPolicy {
      XCTAssertEqual(count, 3)
    } else {
      XCTFail("Expected keepLatest policy")
    }
  }

  func testResetReturnsToBaseline() async {
    let service = InMemoryDownloadConfigurationService(initial: DownloadSettings(
      autoDownloadEnabled: true,
      wifiOnly: false,
      maxConcurrentDownloads: 2,
      retentionPolicy: .keepAll,
      defaultUpdateFrequency: .weekly
    ))
    let controller = DownloadConfigurationController(service: service)
    await controller.loadBaseline()

    controller.setAutoDownloadEnabled(false)
    controller.setMaxConcurrentDownloads(10)
    XCTAssertTrue(controller.hasUnsavedChanges)

    await controller.resetToBaseline()

    XCTAssertTrue(controller.autoDownloadEnabled)
    XCTAssertEqual(controller.maxConcurrentDownloads, 2)
    XCTAssertFalse(controller.hasUnsavedChanges)
  }
}

actor InMemoryDownloadConfigurationService: DownloadConfigurationServicing {
  private var value: DownloadSettings

  init(initial: DownloadSettings) {
    self.value = initial
  }

  func load() async -> DownloadSettings { value }

  func save(_ settings: DownloadSettings) async {
    value = settings
  }

  nonisolated func updatesStream() -> AsyncStream<DownloadSettings> {
    AsyncStream { continuation in
      continuation.onTermination = { _ in }
    }
  }
}

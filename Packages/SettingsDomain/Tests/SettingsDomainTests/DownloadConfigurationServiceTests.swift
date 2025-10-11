import XCTest
import CoreModels
import Persistence
@testable import SettingsDomain

final class DownloadConfigurationServiceTests: XCTestCase {
  func testLoadReturnsDefaultsWhenEmpty() async {
    let suiteName = "download-service-empty-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    let service = DownloadConfigurationService(repository: repository)

    let settings = await service.load()
    XCTAssertEqual(settings, DownloadSettings.default)
  }

  func testSavePersistsAcrossInstances() async {
    let suiteName = "download-service-roundtrip-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    let service = DownloadConfigurationService(repository: repository)
    let expected = DownloadSettings(
      autoDownloadEnabled: true,
      wifiOnly: false,
      maxConcurrentDownloads: 5,
      retentionPolicy: .deleteAfterDays(14),
      defaultUpdateFrequency: .daily
    )

    await service.save(expected)

    let reloaded = await DownloadConfigurationService(repository: repository).load()
    XCTAssertEqual(reloaded, expected)
  }

  func testUpdatesStreamPublishesChanges() async {
    let suiteName = "download-service-stream-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    let service = DownloadConfigurationService(repository: repository)
    let expectation = expectation(description: "Received download update")

    let task = Task {
      var iterator = service.updatesStream().makeAsyncIterator()
      while let next = await iterator.next() {
        if next.maxConcurrentDownloads == 7 {
          expectation.fulfill()
          break
        }
      }
    }

    await service.save(DownloadSettings(
      autoDownloadEnabled: true,
      wifiOnly: true,
      maxConcurrentDownloads: 7,
      retentionPolicy: .keepAll,
      defaultUpdateFrequency: .every12Hours
    ))

    await fulfillment(of: [expectation], timeout: 1.0)
    task.cancel()
  }
}

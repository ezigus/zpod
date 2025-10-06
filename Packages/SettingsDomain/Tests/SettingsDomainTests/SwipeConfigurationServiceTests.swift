import XCTest
import CoreModels
import Persistence
@testable import SettingsDomain

final class SwipeConfigurationServiceTests: XCTestCase {
  func testLoadReturnsDefaultsWhenRepositoryEmpty() async throws {
    // Given
    let suiteName = "swipe-service-empty-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    let service = SwipeConfigurationService(repository: repository)

    // When
    let configuration = await service.load()

    // Then
    XCTAssertEqual(configuration.swipeActions, SwipeActionSettings.default)
    XCTAssertEqual(configuration.hapticStyle, SwipeHapticStyle.medium)
  }

  func testSavePersistsConfigurationAcrossServiceInstances() async throws {
    // Given
    let suiteName = "swipe-service-roundtrip-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    let service = SwipeConfigurationService(repository: repository)
    let expected = SwipeConfiguration(
      swipeActions: SwipeActionSettings(
        leadingActions: [.favorite, .play],
        trailingActions: [.archive, .delete],
        allowFullSwipeLeading: false,
        allowFullSwipeTrailing: true,
        hapticFeedbackEnabled: false
      ),
      hapticStyle: .heavy
    )

    // When
    try await service.save(expected)
    let reloaded = await SwipeConfigurationService(repository: repository).load()

    // Then
    XCTAssertEqual(reloaded, expected)
  }

  func testUpdatesStreamPublishesSavedConfigurations() async throws {
    // Given
    let suiteName = "swipe-service-stream-\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    let service = SwipeConfigurationService(repository: repository)
    let expectation = expectation(description: "Received update")
    expectation.expectedFulfillmentCount = 1

    // When
    let task = Task {
      var iterator = service.updatesStream().makeAsyncIterator()
      while let next = await iterator.next() {
        if next.swipeActions.leadingActions == [.download] {
          expectation.fulfill()
          break
        }
      }
    }

    try await service.save(
      SwipeConfiguration(
        swipeActions: SwipeActionSettings(
          leadingActions: [.download],
          trailingActions: [.play],
          allowFullSwipeLeading: true,
          allowFullSwipeTrailing: false,
          hapticFeedbackEnabled: true
        ),
        hapticStyle: .light
      )
    )

    // Then
    await fulfillment(of: [expectation], timeout: 1.0)
    task.cancel()
  }
}

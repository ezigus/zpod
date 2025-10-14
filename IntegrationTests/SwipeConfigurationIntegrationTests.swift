import XCTest
@testable import CoreModels
@testable import Persistence
@testable import SettingsDomain

/// Integration coverage for the swipe configuration modular pipeline.
///
/// Mirrors Issue 02.1.6.3 acceptance criterion #2: save → relaunch → load
/// persists the latest swipe configuration via the modular service path.
final class SwipeConfigurationIntegrationTests: XCTestCase {
  private var suiteName: String!
  private var repository: UserDefaultsSettingsRepository!

  override func setUpWithError() throws {
    try super.setUpWithError()

    suiteName = "SwipeConfigurationIntegrationTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      XCTFail("Failed to create isolated UserDefaults suite")
      return
    }

    defaults.removePersistentDomain(forName: suiteName)
    repository = UserDefaultsSettingsRepository(suiteName: suiteName)
  }

  override func tearDownWithError() throws {
    if let suiteName {
      UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    repository = nil
    suiteName = nil

    try super.tearDownWithError()
  }

  @MainActor
  func testSwipeConfigurationPersistsAcrossRelaunch() async throws {
    // Given: initial manager
    let initialManager = SettingsManager(repository: repository)
    try await Task.sleep(nanoseconds: 100_000_000) // Allow async bootstrap
    XCTAssertEqual(initialManager.globalUISettings, .default)

    // When: user updates swipe preferences via legacy pathway
    let updatedSwipeActions = SwipeActionSettings(
      leadingActions: [.download, .archive],
      trailingActions: [.play, .favorite],
      allowFullSwipeLeading: false,
      allowFullSwipeTrailing: true,
      hapticFeedbackEnabled: false
    )

    let updatedSettings = UISettings(
      swipeActions: updatedSwipeActions,
      hapticStyle: .heavy
    )

    await initialManager.updateGlobalUISettings(updatedSettings)

    // Then: persistence reflects the new configuration immediately
    let persistedSettings = await repository.loadGlobalUISettings()
    XCTAssertEqual(persistedSettings, updatedSettings)

    // And: a fresh manager observes the saved configuration after "relaunch"
    guard let suiteName else {
      XCTFail("Missing suite name during relaunch")
      return
    }

    let relaunchedRepository = UserDefaultsSettingsRepository(suiteName: suiteName)
    let relaunchedManager = SettingsManager(repository: relaunchedRepository)
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(relaunchedManager.globalUISettings, updatedSettings)

    let relaunchedConfiguration = await relaunchedManager.swipeConfigurationService.load()
    XCTAssertEqual(relaunchedConfiguration.swipeActions, updatedSwipeActions)
    XCTAssertEqual(relaunchedConfiguration.hapticStyle, updatedSettings.hapticStyle)
  }
}

import XCTest
@testable import CoreModels
@testable import SettingsDomain
@testable import Persistence

/// Integration tests verifying that swipe actions configured in settings
/// are properly reflected in the SwipeConfigurationController.
///
/// Related: Issue 02.1.6.6 - Task 2: Episode list integration tests
final class SwipeActionsEpisodeListIntegrationTests: XCTestCase {
  private var suiteName: String!
  private var repository: UserDefaultsSettingsRepository!

  override func setUpWithError() throws {
    try super.setUpWithError()
    suiteName = "SwipeActionsEpisodeListTests.\(UUID().uuidString)"
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
  func testLeadingActionsReflectSettingsConfiguration() async throws {
    let settingsManager = SettingsManager(repository: repository)
    
    let customActions: [SwipeActionType] = [.download, .archive]
    let customSettings = SwipeActionSettings(
      leadingActions: customActions,
      trailingActions: [.delete],
      allowFullSwipeLeading: true,
      allowFullSwipeTrailing: false,
      hapticFeedbackEnabled: true
    )

    await settingsManager.updateGlobalUISettings(UISettings(
      swipeActions: customSettings,
      hapticStyle: .medium
    ))

    let controller = SwipeConfigurationController(service: settingsManager.swipeConfigurationService)
    await controller.loadBaseline()

    XCTAssertEqual(controller.leadingActions, customActions)
    XCTAssertEqual(controller.allowFullSwipeLeading, true)
  }

  @MainActor
  func testTrailingActionsReflectSettingsConfiguration() async throws {
    let settingsManager = SettingsManager(repository: repository)
    
    let customActions: [SwipeActionType] = [.play, .favorite, .share]
    let customSettings = SwipeActionSettings(
      leadingActions: [.markPlayed],
      trailingActions: customActions,
      allowFullSwipeLeading: false,
      allowFullSwipeTrailing: true,
      hapticFeedbackEnabled: false
    )

    await settingsManager.updateGlobalUISettings(UISettings(
      swipeActions: customSettings,
      hapticStyle: .soft
    ))

    let controller = SwipeConfigurationController(service: settingsManager.swipeConfigurationService)
    await controller.loadBaseline()

    XCTAssertEqual(controller.trailingActions, customActions)
    XCTAssertEqual(controller.allowFullSwipeTrailing, true)
  }

  @MainActor
  func testHapticSettingsReflectConfiguration() async throws {
    let settingsManager = SettingsManager(repository: repository)
    
    let customSettings = SwipeActionSettings(
      leadingActions: [.markPlayed],
      trailingActions: [.delete],
      allowFullSwipeLeading: true,
      allowFullSwipeTrailing: false,
      hapticFeedbackEnabled: true
    )

    await settingsManager.updateGlobalUISettings(UISettings(
      swipeActions: customSettings,
      hapticStyle: .rigid
    ))

    let controller = SwipeConfigurationController(service: settingsManager.swipeConfigurationService)
    await controller.loadBaseline()

    XCTAssertEqual(controller.hapticsEnabled, true)
    XCTAssertEqual(controller.hapticStyle, .rigid)
  }

  @MainActor
  func testPlaybackPresetAppliesCorrectActions() async throws {
    let settingsManager = SettingsManager(repository: repository)
    let controller = SwipeConfigurationController(service: settingsManager.swipeConfigurationService)
    await controller.loadBaseline()

    controller.applyPreset(.playbackFocused)

    XCTAssertEqual(controller.leadingActions, SwipeActionSettings.playbackFocused.leadingActions)
    XCTAssertEqual(controller.trailingActions, SwipeActionSettings.playbackFocused.trailingActions)
  }

  @MainActor
  func testOrganizationPresetAppliesCorrectActions() async throws {
    let settingsManager = SettingsManager(repository: repository)
    let controller = SwipeConfigurationController(service: settingsManager.swipeConfigurationService)
    await controller.loadBaseline()

    controller.applyPreset(.organizationFocused)

    XCTAssertEqual(controller.leadingActions, SwipeActionSettings.organizationFocused.leadingActions)
    XCTAssertEqual(controller.trailingActions, SwipeActionSettings.organizationFocused.trailingActions)
  }

  @MainActor
  func testDownloadPresetAppliesCorrectActions() async throws {
    let settingsManager = SettingsManager(repository: repository)
    let controller = SwipeConfigurationController(service: settingsManager.swipeConfigurationService)
    await controller.loadBaseline()

    controller.applyPreset(.downloadFocused)

    XCTAssertEqual(controller.leadingActions, SwipeActionSettings.downloadFocused.leadingActions)
    XCTAssertEqual(controller.trailingActions, SwipeActionSettings.downloadFocused.trailingActions)
  }
}

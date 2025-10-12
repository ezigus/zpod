import XCTest
import CoreModels
@testable import SettingsDomain
@testable import Persistence

@MainActor
final class SettingsManagerFeatureRegistryTests: XCTestCase {
  private var userDefaults: UserDefaults!
  private var repository: UserDefaultsSettingsRepository!
  private var settingsManager: SettingsManager!
  private var suiteName: String!

  override func setUp() async throws {
    suiteName = "test.registry.settings.\(UUID().uuidString)"
    userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    settingsManager = SettingsManager(repository: repository)

    // Allow async initialization tasks to settle
    try await Task.sleep(nanoseconds: 50_000_000)
  }

  override func tearDown() async throws {
    if let suiteName {
      userDefaults.removePersistentDomain(forName: suiteName)
    }
    suiteName = nil
    userDefaults = nil
    repository = nil
    settingsManager = nil
  }

  func testRegistryContainsDescriptors() async throws {
    let descriptors = await settingsManager.featureConfigurationRegistry.allDescriptors()
    XCTAssertTrue(
      descriptors.contains(where: { $0.id == "notifications" }),
      "Registry should include the notifications descriptor"
    )
    XCTAssertTrue(
      descriptors.contains(where: { $0.id == "appearance" }),
      "Registry should include the appearance descriptor"
    )
    XCTAssertTrue(
      descriptors.contains(where: { $0.id == "smartListAutomation" }),
      "Registry should include the smart list automation descriptor"
    )
    XCTAssertTrue(
      descriptors.contains(where: { $0.id == "swipeActions" }),
      "Registry should include the swipe configuration descriptor"
    )
  }

  func testRegistryControllerFactoryReturnsSwipeController() async throws {
    let controller = await settingsManager.featureConfigurationRegistry.controller(for: "swipeActions")
    let swipeController = controller as? SwipeConfigurationController
    XCTAssertNotNil(swipeController)

    await swipeController?.loadBaseline()
    XCTAssertEqual(
      swipeController?.leadingActions,
      settingsManager.globalUISettings.swipeActions.leadingActions,
      "Swipe controller should load baseline leading actions"
    )
  }

  func testRegistryControllerFactoryReturnsNotificationsController() async throws {
    let controller = await settingsManager.featureConfigurationRegistry.controller(for: "notifications")
    let notificationsController = controller as? NotificationsConfigurationController
    XCTAssertNotNil(notificationsController)

    await notificationsController?.loadBaseline()
    XCTAssertEqual(
      notificationsController?.deliverySchedule,
      settingsManager.globalNotificationSettings.deliverySchedule,
      "Notifications controller should load baseline schedule"
    )
  }

  func testRegistryControllerFactoryReturnsAppearanceController() async throws {
    let controller = await settingsManager.featureConfigurationRegistry.controller(for: "appearance")
    let appearanceController = controller as? AppearanceConfigurationController
    XCTAssertNotNil(appearanceController)

    await appearanceController?.loadBaseline()
    XCTAssertEqual(
      appearanceController?.typographyScale,
      settingsManager.globalAppearanceSettings.typographyScale,
      accuracy: 0.0001,
      "Appearance controller should load baseline scale"
    )
  }

  func testRegistryControllerFactoryReturnsSmartListAutomationController() async throws {
    let controller = await settingsManager.featureConfigurationRegistry.controller(for: "smartListAutomation")
    let automationController = controller as? SmartListAutomationConfigurationController
    XCTAssertNotNil(automationController)

    await automationController?.loadBaseline()
    XCTAssertEqual(
      automationController?.maxRefreshPerCycle,
      settingsManager.globalSmartListAutomationSettings.maxRefreshPerCycle,
      "Smart list automation controller should load baseline configuration"
    )
  }

  func testManagerProvidesPreloadedSwipeController() async throws {
    let controller = settingsManager.makeSwipeConfigurationController()
    XCTAssertEqual(
      controller.leadingActions,
      settingsManager.globalUISettings.swipeActions.leadingActions,
      "Factory controller should mirror current global UI settings"
    )
  }

  func testManagerProvidesPreloadedNotificationsController() async throws {
    let controller = settingsManager.makeNotificationsConfigurationController()
    XCTAssertEqual(
      controller.deliverySchedule,
      settingsManager.globalNotificationSettings.deliverySchedule,
      "Factory notifications controller should mirror current notification settings"
    )
  }

  func testManagerProvidesPreloadedAppearanceController() async throws {
    let controller = settingsManager.makeAppearanceConfigurationController()
    XCTAssertEqual(
      controller.typographyScale,
      settingsManager.globalAppearanceSettings.typographyScale,
      accuracy: 0.0001,
      "Factory appearance controller should mirror current appearance settings"
    )
  }

  func testManagerProvidesPreloadedSmartListAutomationController() async throws {
    let controller = settingsManager.makeSmartListAutomationConfigurationController()
    XCTAssertEqual(
      controller.maxRefreshPerCycle,
      settingsManager.globalSmartListAutomationSettings.maxRefreshPerCycle,
      "Factory smart list controller should mirror current automation settings"
    )
  }

  func testGroupedDescriptorsProducesSections() async throws {
    let sections = await settingsManager.allFeatureSections()
    XCTAssertEqual(sections.count, 6)

    XCTAssertEqual(sections[0].title, "Engagement")
    XCTAssertEqual(sections[0].descriptors.first?.id, "notifications")

    XCTAssertEqual(sections[1].title, "Personalization")
    XCTAssertEqual(sections[1].descriptors.first?.id, "appearance")

    XCTAssertEqual(sections[2].title, "Automation")
    XCTAssertEqual(sections[2].descriptors.first?.id, "smartListAutomation")

    XCTAssertEqual(sections[3].title, "Interaction")
    XCTAssertEqual(sections[3].descriptors.first?.id, "swipeActions")

    XCTAssertEqual(sections[4].title, "Playback")
    XCTAssertEqual(sections[4].descriptors.first?.id, "playbackPreferences")

    XCTAssertEqual(sections[5].title, "Downloads")
    XCTAssertEqual(sections[5].descriptors.first?.id, "downloadPolicies")
  }

  func testControllerCachingReturnsSameInstance() async throws {
    let first = await settingsManager.controller(forFeature: "swipeActions") as? SwipeConfigurationController
    let second = await settingsManager.controller(forFeature: "swipeActions") as? SwipeConfigurationController

    XCTAssertNotNil(first)
    XCTAssertNotNil(second)
    if let first, let second {
      XCTAssertTrue(first === second, "controller(forFeature:) should cache instances by default")
    }
  }

  func testNotificationsControllerCaching() async throws {
    let first = await settingsManager.controller(forFeature: "notifications") as? NotificationsConfigurationController
    let second = await settingsManager.controller(forFeature: "notifications") as? NotificationsConfigurationController

    XCTAssertNotNil(first)
    XCTAssertNotNil(second)
    if let first, let second {
      XCTAssertTrue(first === second, "Notifications controller should be cached by default")
    }
  }

  func testNotificationsControllerBypassReturnsNewInstance() async throws {
    let cached = await settingsManager.controller(forFeature: "notifications") as? NotificationsConfigurationController
    let fresh = await settingsManager.controller(forFeature: "notifications", useCache: false) as? NotificationsConfigurationController

    XCTAssertNotNil(cached)
    XCTAssertNotNil(fresh)
    if let cached, let fresh {
      XCTAssertFalse(cached === fresh, "Bypassing cache should return new notifications controller")
    }
  }

  func testAppearanceControllerCaching() async throws {
    let first = await settingsManager.controller(forFeature: "appearance") as? AppearanceConfigurationController
    let second = await settingsManager.controller(forFeature: "appearance") as? AppearanceConfigurationController

    XCTAssertNotNil(first)
    XCTAssertNotNil(second)
    if let first, let second {
      XCTAssertTrue(first === second, "Appearance controller should be cached by default")
    }
  }

  func testAppearanceControllerBypassReturnsNewInstance() async throws {
    let cached = await settingsManager.controller(forFeature: "appearance") as? AppearanceConfigurationController
    let fresh = await settingsManager.controller(forFeature: "appearance", useCache: false) as? AppearanceConfigurationController

    XCTAssertNotNil(cached)
    XCTAssertNotNil(fresh)
    if let cached, let fresh {
      XCTAssertFalse(cached === fresh, "Bypassing cache should return new appearance controller")
    }
  }

  func testSmartListControllerCaching() async throws {
    let first = await settingsManager.controller(forFeature: "smartListAutomation") as? SmartListAutomationConfigurationController
    let second = await settingsManager.controller(forFeature: "smartListAutomation") as? SmartListAutomationConfigurationController

    XCTAssertNotNil(first)
    XCTAssertNotNil(second)
    if let first, let second {
      XCTAssertTrue(first === second, "Smart list controller should be cached by default")
    }
  }

  func testSmartListControllerBypassReturnsNewInstance() async throws {
    let cached = await settingsManager.controller(forFeature: "smartListAutomation") as? SmartListAutomationConfigurationController
    let fresh = await settingsManager.controller(forFeature: "smartListAutomation", useCache: false) as? SmartListAutomationConfigurationController

    XCTAssertNotNil(cached)
    XCTAssertNotNil(fresh)
    if let cached, let fresh {
      XCTAssertFalse(cached === fresh, "Bypassing cache should return new smart list controller")
    }
  }

  func testControllerCacheBypassReturnsNewInstance() async throws {
    let cached = await settingsManager.controller(forFeature: "swipeActions") as? SwipeConfigurationController
    let fresh = await settingsManager.controller(forFeature: "swipeActions", useCache: false) as? SwipeConfigurationController

    XCTAssertNotNil(cached)
    XCTAssertNotNil(fresh)
    if let cached, let fresh {
      XCTAssertFalse(cached === fresh, "Requesting controller without cache should yield a new instance")
    }
  }

  func testPlaybackControllerCaching() async throws {
    let first = await settingsManager.controller(forFeature: "playbackPreferences") as? PlaybackConfigurationController
    let second = await settingsManager.controller(forFeature: "playbackPreferences") as? PlaybackConfigurationController

    XCTAssertNotNil(first)
    XCTAssertNotNil(second)
    if let first, let second {
      XCTAssertTrue(first === second)
    }
  }

  func testPlaybackControllerBypassReturnsNewInstance() async throws {
    let cached = await settingsManager.controller(forFeature: "playbackPreferences") as? PlaybackConfigurationController
    let fresh = await settingsManager.controller(forFeature: "playbackPreferences", useCache: false) as? PlaybackConfigurationController

    XCTAssertNotNil(cached)
    XCTAssertNotNil(fresh)
    if let cached, let fresh {
      XCTAssertFalse(cached === fresh)
    }
  }

  func testDownloadControllerCaching() async throws {
    let first = await settingsManager.controller(forFeature: "downloadPolicies") as? DownloadConfigurationController
    let second = await settingsManager.controller(forFeature: "downloadPolicies") as? DownloadConfigurationController

    XCTAssertNotNil(first)
    XCTAssertNotNil(second)
    if let first, let second {
      XCTAssertTrue(first === second)
    }
  }

  func testDownloadControllerBypassReturnsNewInstance() async throws {
    let cached = await settingsManager.controller(forFeature: "downloadPolicies") as? DownloadConfigurationController
    let fresh = await settingsManager.controller(forFeature: "downloadPolicies", useCache: false) as? DownloadConfigurationController

    XCTAssertNotNil(cached)
    XCTAssertNotNil(fresh)
    if let cached, let fresh {
      XCTAssertFalse(cached === fresh)
    }
  }
}

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

  func testRegistryContainsSwipeDescriptor() async throws {
    let descriptors = await settingsManager.featureConfigurationRegistry.allDescriptors()
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

  func testManagerProvidesPreloadedSwipeController() async throws {
    let controller = settingsManager.makeSwipeConfigurationController()
    XCTAssertEqual(
      controller.leadingActions,
      settingsManager.globalUISettings.swipeActions.leadingActions,
      "Factory controller should mirror current global UI settings"
    )
  }

  func testGroupedDescriptorsProducesSections() async throws {
    let sections = await settingsManager.allFeatureSections()
    XCTAssertEqual(sections.count, 1)
    XCTAssertEqual(sections.first?.title, "Interaction")
    XCTAssertEqual(sections.first?.descriptors.first?.id, "swipeActions")
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

  func testControllerCacheBypassReturnsNewInstance() async throws {
    let cached = await settingsManager.controller(forFeature: "swipeActions") as? SwipeConfigurationController
    let fresh = await settingsManager.controller(forFeature: "swipeActions", useCache: false) as? SwipeConfigurationController

    XCTAssertNotNil(cached)
    XCTAssertNotNil(fresh)
    if let cached, let fresh {
      XCTAssertFalse(cached === fresh, "Requesting controller without cache should yield a new instance")
    }
  }
}

import XCTest
@testable import SettingsDomain

final class FeatureConfigurationRegistryTests: XCTestCase {
  func testAllDescriptorsReturnsRegisteredFeaturesInOrder() async {
    // Given
    let featureA = StubFeature(id: "swipe", title: "Swipe", available: true)
    let featureB = StubFeature(id: "playback", title: "Playback", available: true)
    let registry = FeatureConfigurationRegistry(features: [featureA, featureB])

    // When
    let descriptors = await registry.allDescriptors()

    // Then
    XCTAssertEqual(descriptors.map { $0.id }, ["swipe", "playback"])
  }

  func testUnavailableFeaturesAreFiltered() async {
    // Given
    let available = StubFeature(id: "available", title: "Available", available: true)
    let unavailable = StubFeature(id: "unavailable", title: "Unavailable", available: false)
    let registry = FeatureConfigurationRegistry(features: [available, unavailable])

    // When
    let descriptors = await registry.allDescriptors()

    // Then
    XCTAssertEqual(descriptors.map { $0.id }, ["available"])
  }

  @MainActor
  func testControllerFactoryReturnsFeatureController() async {
    // Given
    let feature = StubFeature(id: "swipe", title: "Swipe", available: true)
    let registry = FeatureConfigurationRegistry(features: [feature])

    // When
    let controller = await registry.controller(for: "swipe") as? StubController

    // Then
    XCTAssertNotNil(controller)
    XCTAssertEqual(controller?.identifier, "swipe")
  }
}

final class StubFeature: ConfigurableFeature, @unchecked Sendable {
  let id: String
  let title: String
  let available: Bool

  init(id: String, title: String, available: Bool) {
    self.id = id
    self.title = title
    self.available = available
  }

  var descriptor: FeatureConfigurationDescriptor {
    FeatureConfigurationDescriptor(id: id, title: title, iconSystemName: "gear")
  }

  func isAvailable() async -> Bool { available }

  @MainActor
  func makeController() -> any FeatureConfigurationControlling {
    StubController(identifier: id)
  }
}

@MainActor
final class StubController: FeatureConfigurationControlling {
  let identifier: String

  init(identifier: String) {
    self.identifier = identifier
  }

  func resetToBaseline() async {}
}

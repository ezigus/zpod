import CoreModels
import Foundation

public final class SwipeConfigurationFeature: ConfigurableFeature, @unchecked Sendable {
  private let descriptorValue: FeatureConfigurationDescriptor
  private let service: SwipeConfigurationServicing

  public init(service: SwipeConfigurationServicing) {
    self.service = service
    self.descriptorValue = FeatureConfigurationDescriptor(
      id: "swipeActions",
      title: "Swipe Actions",
      iconSystemName: "hand.draw",
      category: "Interaction",
      analyticsKey: "settings.swipeActions"
    )
  }

  public var descriptor: FeatureConfigurationDescriptor { descriptorValue }

  public func isAvailable() async -> Bool {
    true
  }

  @MainActor
  public func makeController() -> any FeatureConfigurationControlling {
    SwipeConfigurationController(service: service)
  }
}

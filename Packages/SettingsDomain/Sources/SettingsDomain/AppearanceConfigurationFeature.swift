import Foundation
import CoreModels

public final class AppearanceConfigurationFeature: ConfigurableFeature, @unchecked Sendable {
  private let descriptorValue: FeatureConfigurationDescriptor
  private let service: AppearanceConfigurationServicing

  public init(service: AppearanceConfigurationServicing) {
    self.service = service
    self.descriptorValue = FeatureConfigurationDescriptor(
      id: "appearance",
      title: "Appearance",
      iconSystemName: "paintbrush",
      category: "Personalization",
      analyticsKey: "settings.appearance"
    )
  }

  public var descriptor: FeatureConfigurationDescriptor { descriptorValue }

  public func isAvailable() async -> Bool {
    true
  }

  @MainActor
  public func makeController() -> any FeatureConfigurationControlling {
    AppearanceConfigurationController(service: service)
  }
}


import Foundation
import CoreModels

public final class SmartListAutomationConfigurationFeature: ConfigurableFeature, @unchecked Sendable {
  private let descriptorValue: FeatureConfigurationDescriptor
  private let service: SmartListAutomationConfigurationServicing

  public init(service: SmartListAutomationConfigurationServicing) {
    self.service = service
    self.descriptorValue = FeatureConfigurationDescriptor(
      id: "smartListAutomation",
      title: "Smart List Automation",
      iconSystemName: "tray.full",
      category: "Automation",
      analyticsKey: "settings.smartListAutomation"
    )
  }

  public var descriptor: FeatureConfigurationDescriptor { descriptorValue }

  public func isAvailable() async -> Bool { true }

  @MainActor
  public func makeController() -> any FeatureConfigurationControlling {
    SmartListAutomationConfigurationController(service: service)
  }
}


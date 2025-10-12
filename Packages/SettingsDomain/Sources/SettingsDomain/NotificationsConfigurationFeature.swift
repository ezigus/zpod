import Foundation
import CoreModels

public final class NotificationsConfigurationFeature: ConfigurableFeature, @unchecked Sendable {
  private let descriptorValue: FeatureConfigurationDescriptor
  private let service: NotificationsConfigurationServicing

  public init(service: NotificationsConfigurationServicing) {
    self.service = service
    self.descriptorValue = FeatureConfigurationDescriptor(
      id: "notifications",
      title: "Notifications",
      iconSystemName: "bell.badge",
      category: "Engagement",
      analyticsKey: "settings.notifications"
    )
  }

  public var descriptor: FeatureConfigurationDescriptor { descriptorValue }

  public func isAvailable() async -> Bool {
    true
  }

  @MainActor
  public func makeController() -> any FeatureConfigurationControlling {
    NotificationsConfigurationController(service: service)
  }
}


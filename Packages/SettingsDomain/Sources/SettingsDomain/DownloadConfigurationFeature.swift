import CoreModels
import Foundation

public final class DownloadConfigurationFeature: ConfigurableFeature, @unchecked Sendable {
  private let descriptorValue: FeatureConfigurationDescriptor
  private let service: DownloadConfigurationServicing

  public init(service: DownloadConfigurationServicing) {
    self.service = service
    self.descriptorValue = FeatureConfigurationDescriptor(
      id: "downloadPolicies",
      title: "Download Policies",
      iconSystemName: "tray.and.arrow.down",
      category: "Downloads",
      analyticsKey: "settings.downloads"
    )
  }

  public var descriptor: FeatureConfigurationDescriptor { descriptorValue }

  public func isAvailable() async -> Bool { true }

  @MainActor
  public func makeController() -> any FeatureConfigurationControlling {
    DownloadConfigurationController(service: service)
  }
}

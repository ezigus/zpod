import Foundation

public struct FeatureConfigurationDescriptor: Equatable, Sendable {
  public let id: String
  public let title: String
  public let iconSystemName: String
  public let category: String?
  public let analyticsKey: String?

  public init(
    id: String,
    title: String,
    iconSystemName: String,
    category: String? = nil,
    analyticsKey: String? = nil
  ) {
    self.id = id
    self.title = title
    self.iconSystemName = iconSystemName
    self.category = category
    self.analyticsKey = analyticsKey
  }
}

@MainActor
public protocol FeatureConfigurationControlling: AnyObject {
  func resetToBaseline() async
}

public protocol ConfigurableFeature: AnyObject, Sendable {
  var descriptor: FeatureConfigurationDescriptor { get }
  func isAvailable() async -> Bool
  @MainActor func makeController() -> any FeatureConfigurationControlling
}

public struct FeatureConfigurationRegistry {
  private let features: [ConfigurableFeature]

  public init(features: [ConfigurableFeature]) {
    self.features = features
  }

  @MainActor
  public func allDescriptors() async -> [FeatureConfigurationDescriptor] {
    var orderedDescriptors: [FeatureConfigurationDescriptor] = []
    for feature in features {
      guard await feature.isAvailable() else { continue }
      orderedDescriptors.append(feature.descriptor)
    }
    return orderedDescriptors
  }

  @MainActor
  public func controller(for id: String) async -> (any FeatureConfigurationControlling)? {
    guard let feature = features.first(where: { $0.descriptor.id == id }) else {
      return nil
    }
    guard await feature.isAvailable() else { return nil }
    return feature.makeController()
  }
}

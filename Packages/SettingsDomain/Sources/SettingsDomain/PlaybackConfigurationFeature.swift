import CoreModels
import Foundation

public final class PlaybackConfigurationFeature: ConfigurableFeature, @unchecked Sendable {
  private let descriptorValue: FeatureConfigurationDescriptor
  private let service: PlaybackConfigurationServicing

  public init(service: PlaybackConfigurationServicing) {
    self.service = service
    self.descriptorValue = FeatureConfigurationDescriptor(
      id: "playbackPreferences",
      title: "Playback Preferences",
      iconSystemName: "dial.medium",
      category: "Playback",
      analyticsKey: "settings.playback"
    )
  }

  public var descriptor: FeatureConfigurationDescriptor { descriptorValue }

  public func isAvailable() async -> Bool { true }

  @MainActor
  public func makeController() -> any FeatureConfigurationControlling {
    PlaybackConfigurationController(service: service)
  }
}

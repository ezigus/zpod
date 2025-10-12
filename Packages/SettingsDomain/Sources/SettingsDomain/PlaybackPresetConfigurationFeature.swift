import Foundation
import CoreModels

public final class PlaybackPresetConfigurationFeature: ConfigurableFeature, @unchecked Sendable {
  private let descriptorValue: FeatureConfigurationDescriptor
  private let service: PlaybackPresetConfigurationServicing
  private let applyPresetHandler: (PlaybackPreset?, PlaybackPresetLibrary) -> Void

  public init(
    service: PlaybackPresetConfigurationServicing,
    applyPresetHandler: @escaping (PlaybackPreset?, PlaybackPresetLibrary) -> Void
  ) {
    self.service = service
    self.applyPresetHandler = applyPresetHandler
    self.descriptorValue = FeatureConfigurationDescriptor(
      id: "playbackPresets",
      title: "Playback Presets",
      iconSystemName: "list.bullet.rectangle",
      category: "Playback",
      analyticsKey: "settings.playbackPresets"
    )
  }

  public var descriptor: FeatureConfigurationDescriptor { descriptorValue }

  public func isAvailable() async -> Bool { true }

  @MainActor
  public func makeController() -> any FeatureConfigurationControlling {
    PlaybackPresetConfigurationController(service: service, applyPresetHandler: applyPresetHandler)
  }
}


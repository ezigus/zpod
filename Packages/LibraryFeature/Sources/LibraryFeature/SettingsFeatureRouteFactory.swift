import SettingsDomain
import SwiftUI

@MainActor
struct SettingsFeatureRoute {
  let loadBaseline: () async -> Void
  let destination: () -> AnyView
}

@MainActor
enum SettingsFeatureRouteFactory {
  static func makeRoute(
    descriptorID: String,
    controller: any FeatureConfigurationControlling
  ) -> SettingsFeatureRoute? {
    switch descriptorID {
    case "swipeActions":
      guard let controller = controller as? SwipeConfigurationController else { return nil }
      return SettingsFeatureRoute(
        loadBaseline: { await controller.loadBaseline() },
        destination: { AnyView(SwipeActionConfigurationView(controller: controller)) }
      )

    case "playbackPreferences":
      guard let controller = controller as? PlaybackConfigurationController else { return nil }
      return SettingsFeatureRoute(
        loadBaseline: { await controller.loadBaseline() },
        destination: { AnyView(PlaybackConfigurationView(controller: controller)) }
      )

    case "downloadPolicies":
      guard let controller = controller as? DownloadConfigurationController else { return nil }
      return SettingsFeatureRoute(
        loadBaseline: { await controller.loadBaseline() },
        destination: { AnyView(DownloadConfigurationView(controller: controller)) }
      )

    default:
      return nil
    }
  }
}

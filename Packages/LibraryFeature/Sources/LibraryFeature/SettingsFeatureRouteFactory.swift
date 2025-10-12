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
    case "notifications":
      guard let controller = controller as? NotificationsConfigurationController else { return nil }
      return SettingsFeatureRoute(
        loadBaseline: { await controller.loadBaseline() },
        destination: { AnyView(NotificationsConfigurationView(controller: controller)) }
      )
    case "appearance":
      guard let controller = controller as? AppearanceConfigurationController else { return nil }
      return SettingsFeatureRoute(
        loadBaseline: { await controller.loadBaseline() },
        destination: { AnyView(AppearanceConfigurationView(controller: controller)) }
      )
    case "smartListAutomation":
      guard let controller = controller as? SmartListAutomationConfigurationController else { return nil }
      return SettingsFeatureRoute(
        loadBaseline: { await controller.loadBaseline() },
        destination: { AnyView(SmartListAutomationConfigurationView(controller: controller)) }
      )
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
    case "playbackPresets":
      guard let controller = controller as? PlaybackPresetConfigurationController else { return nil }
      return SettingsFeatureRoute(
        loadBaseline: { await controller.loadBaseline() },
        destination: { AnyView(PlaybackPresetConfigurationView(controller: controller)) }
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

import SettingsDomain
import SwiftUI

struct SettingsHomeView: View {
  @ObservedObject var settingsManager: SettingsManager
  @State private var sections: [FeatureConfigurationSection] = []
  @State private var isLoading = true

  var body: some View {
    NavigationStack {
      List {
        ForEach(sections) { section in
          Section(section.title ?? "General") {
            ForEach(section.descriptors, id: \.id) { descriptor in
              NavigationLink(destination: SettingsFeatureDetailView(descriptor: descriptor, settingsManager: settingsManager)) {
                Label(descriptor.title, systemImage: descriptor.iconSystemName)
                  .accessibilityIdentifier("Settings.Feature.Label.\(descriptor.id)")
              }
              .accessibilityIdentifier("Settings.Feature.\(descriptor.id)")
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .overlay {
        overlayContent()
      }
      .navigationTitle("Settings")
      .task { await loadDescriptors() }
      .refreshable { await loadDescriptors() }
    }
  }

  @MainActor
  private func loadDescriptors() async {
    isLoading = true
    sections = await settingsManager.allFeatureSections()
    isLoading = false
  }

  @ViewBuilder
  private func overlayContent() -> some View {
    if isLoading {
      ProgressView("Loading Settings…")
        .accessibilityIdentifier("Settings.Loading")
    } else if sections.isEmpty {
      ContentUnavailableView(
        label: {
          Label("No Configurable Features", systemImage: "gearshape")
        },
        description: {
          Text("Feature modules will appear here once configuration is available.")
        }
      )
      .accessibilityIdentifier("Settings.EmptyState")
    }
  }

}

private struct SettingsFeatureDetailView: View {
  let descriptor: FeatureConfigurationDescriptor
  @ObservedObject var settingsManager: SettingsManager
  @State private var loadState: LoadState = .loading
  @State private var loadedContent: LoadedContent?

  private enum LoadState {
    case loading
    case ready
    case unsupported
    case failure
  }

  private enum LoadedContent {
    case swipe(SwipeConfigurationController)
    case playback(PlaybackConfigurationController)
  }

  var body: some View {
    content
      .navigationTitle(descriptor.title)
      .task(id: descriptor.id) {
        await loadControllerIfNeeded()
      }
  }

  @ViewBuilder
  private var content: some View {
    switch loadState {
    case .loading:
      ProgressView("Loading…")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("Settings.Feature.Loading")
    case .ready:
      readyContentView
    case .unsupported:
      ContentUnavailableView(
        label: { Label("Coming Soon", systemImage: "hammer") },
        description: { Text("This configuration will be available in a future update.") }
      )
      .accessibilityIdentifier("Settings.Feature.Unsupported")
    case .failure:
      fallbackUnavailable
    }
  }

  @MainActor
  private func loadControllerIfNeeded() async {
    guard loadState != .ready else { return }

    loadState = .loading

    guard let controller = await settingsManager.controller(forFeature: descriptor.id) else {
      loadState = .failure
      return
    }

    if let swipe = controller as? SwipeConfigurationController {
      loadedContent = .swipe(swipe)
      await swipe.loadBaseline()
      loadState = .ready
      return
    }

    if let playback = controller as? PlaybackConfigurationController {
      loadedContent = .playback(playback)
      await playback.loadBaseline()
      loadState = .ready
      return
    }

    loadState = .unsupported
  }

  @ViewBuilder
  private var fallbackUnavailable: some View {
    ContentUnavailableView(
      label: { Label("Feature Unavailable", systemImage: "gearshape") },
      description: { Text("Unable to load configuration for this feature right now.") }
    )
    .accessibilityIdentifier("Settings.Feature.Unavailable")
  }

  @ViewBuilder
  private var readyContentView: some View {
    if let loadedContent {
      switch loadedContent {
      case .swipe(let controller):
        SwipeActionConfigurationView(controller: controller)
      case .playback(let controller):
        PlaybackConfigurationView(controller: controller)
      }
    } else {
      fallbackUnavailable
    }
  }
}

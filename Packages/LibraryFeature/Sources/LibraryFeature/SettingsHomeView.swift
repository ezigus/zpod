import SettingsDomain
import SwiftUI

struct SettingsHomeView: View {
  @ObservedObject var settingsManager: SettingsManager
  @State private var descriptors: [FeatureConfigurationDescriptor] = []
  @State private var isLoading = true

  var body: some View {
    NavigationStack {
      List {
        if !descriptors.isEmpty {
          Section("Features") {
            ForEach(descriptors, id: \.id) { descriptor in
              NavigationLink(destination: destination(for: descriptor)) {
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
    descriptors = await settingsManager.allFeatureDescriptors()
    isLoading = false
  }

  @ViewBuilder
  private func overlayContent() -> some View {
    if isLoading {
      ProgressView("Loading Settings…")
        .accessibilityIdentifier("Settings.Loading")
    } else if descriptors.isEmpty {
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

  @ViewBuilder
  private func destination(for descriptor: FeatureConfigurationDescriptor) -> some View {
    switch descriptor.id {
    case "swipeActions":
      SwipeSettingsDetailView(settingsManager: settingsManager)
    default:
      Text("Feature not yet available.")
        .foregroundStyle(.secondary)
        .navigationTitle(descriptor.title)
    }
  }
}

private struct SwipeSettingsDetailView: View {
  @ObservedObject private var settingsManager: SettingsManager
  @StateObject private var controller: SwipeConfigurationController

  init(settingsManager: SettingsManager) {
    self.settingsManager = settingsManager
    _controller = StateObject(wrappedValue: settingsManager.makeSwipeConfigurationController())
  }

  var body: some View {
    SwipeActionConfigurationView(controller: controller)
      .task { await controller.loadBaseline() }
  }
}

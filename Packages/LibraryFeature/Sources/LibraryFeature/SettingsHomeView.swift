import SettingsDomain
import SwiftUI
import UIKit
import SharedUtilities

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
      .platformInsetGroupedListStyle()
      .overlay {
        overlayContent()
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .modifier(NavigationBarAccessibilityModifier(identifier: "Settings"))
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
  @State private var route: SettingsFeatureRoute?

  private enum LoadState {
    case loading
    case ready
    case unsupported
    case failure
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

    guard let resolvedRoute = SettingsFeatureRouteFactory.makeRoute(
      descriptorID: descriptor.id,
      controller: controller
    ) else {
      loadState = .unsupported
      return
    }

    route = resolvedRoute
    await resolvedRoute.loadBaseline()
    loadState = .ready
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
    if let route {
      route.destination()
    } else {
      fallbackUnavailable
    }
  }
}

// MARK: - Navigation Bar Accessibility Helper

/// Modifier to set accessibility identifier on SwiftUI navigation bar
private struct NavigationBarAccessibilityModifier: ViewModifier {
  let identifier: String

  func body(content: Content) -> some View {
    content
      .background(
        NavigationBarAccessibilityHelper(identifier: identifier)
          .frame(height: 0)
      )
  }
}

/// Helper to tag the native navigation bar with accessibility identifier
private struct NavigationBarAccessibilityHelper: UIViewRepresentable {
  let identifier: String

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      // Find the navigation bar and set its accessibility identifier
      if let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first?.windows.first,
        let navBar = findNavigationBar(in: window) {
        navBar.accessibilityIdentifier = identifier
      }
    }
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {}

  private func findNavigationBar(in view: UIView) -> UINavigationBar? {
    if let navBar = view as? UINavigationBar {
      return navBar
    }
    for subview in view.subviews {
      if let navBar = findNavigationBar(in: subview) {
        return navBar
      }
    }
    return nil
  }
}

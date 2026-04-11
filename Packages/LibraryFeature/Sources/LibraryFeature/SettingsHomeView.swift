import FeedParsing
import Networking
import SettingsDomain
import SharedUtilities
import SwiftUI
import UniformTypeIdentifiers

struct SettingsHomeView: View {
  @ObservedObject var settingsManager: SettingsManager
  @State private var sections: [FeatureConfigurationSection] = []
  @State private var isLoading = true
  @State private var orphanedCount: Int = 0
  @State private var isExportPresented = false
  @State private var exportDocument: OPMLFileDocument?
  @State private var showExportError = false
  @State private var exportErrorMessage = ""

  var body: some View {
    NavigationStack {
      List {
        Section("Storage") {
          NavigationLink {
            StorageManagementView()
          } label: {
            Label("Manage Storage", systemImage: "square.stack.3d.up")
              .accessibilityIdentifier("Settings.ManageStorage.Label")
          }
          .accessibilityIdentifier("Settings.ManageStorage")

          NavigationLink {
            OrphanedEpisodesView(
              viewModel: OrphanedEpisodesViewModel(
                podcastManager: PlaybackEnvironment.podcastManager
              )
            )
          } label: {
            Label("Orphaned Episodes", systemImage: "tray.full")
              .accessibilityIdentifier("Settings.Orphaned.Label")
              .badge(orphanedCount)
          }
          .accessibilityIdentifier("Settings.Orphaned")
        }

        Section("Data & Subscriptions") {
          NavigationLink {
            // Capture podcastManager on the MainActor (view body) before the async closure.
            let podcastManager = PlaybackEnvironment.podcastManager
            OPMLImportSettingsView(
              viewModel: OPMLImportViewModel(
                importService: OPMLImportService(
                  opmlParser: XMLOPMLParser(),
                  subscriptionService: OPMLSubscriptionAdapter { urlString in
                    // Build the Networking stack here to avoid a naming conflict between the
                    // `FeedParsing` module and the `Networking.FeedParsing` protocol in
                    // OPMLSubscriptionAdapter.swift.
                    let service = Networking.SubscriptionService(
                      dataLoader: Networking.PassthroughFeedDataLoader { url in
                        let (data, _) = try await URLSession.shared.data(from: url)
                        return data
                      },
                      parser: NetworkingRSSBridge(),
                      podcastManager: podcastManager
                    )
                    _ = try await service.subscribe(urlString: urlString)
                  }
                )
              )
            )
          } label: {
            Label("OPML Import", systemImage: "square.and.arrow.down")
              .accessibilityIdentifier("Settings.DataSubscriptions.OPMLImport.Label")
          }
          .accessibilityIdentifier("Settings.DataSubscriptions.OPMLImport")

          Button {
            exportOPML()
          } label: {
            Label("Export Subscriptions (OPML)", systemImage: "square.and.arrow.up")
              .accessibilityIdentifier("Settings.ExportOPML.Label")
          }
          .accessibilityIdentifier("Settings.ExportOPML")
        }

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
      .accessibilityIdentifier("Settings.Content")
      .platformInsetGroupedListStyle()
      .overlay {
        overlayContent()
          .allowsHitTesting(false)
      }
      .navigationTitle("Settings")
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .navigationBarAccessibilityIdentifier("Settings")
      .task {
        await loadDescriptors()
        await refreshOrphanedCount()
      }
      .refreshable {
        await loadDescriptors()
        await refreshOrphanedCount()
      }
      .fileExporter(
        isPresented: $isExportPresented,
        document: exportDocument,
        contentType: UTType(filenameExtension: "opml") ?? .xml,
        defaultFilename: "subscriptions.opml"
      ) { result in
        defer { exportDocument = nil }
        if case .failure(let error) = result {
          exportErrorMessage = error.localizedDescription
          showExportError = true
        }
      }
      .alert("Export Failed", isPresented: $showExportError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(exportErrorMessage)
      }
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

  @MainActor
  private func refreshOrphanedCount() async {
    orphanedCount = PlaybackEnvironment.podcastManager.fetchOrphanedEpisodes().count
  }

  @MainActor
  private func exportOPML() {
    // PlaybackEnvironment.podcastManager is always non-nil: CarPlayDependencyRegistry falls
    // back to EmptyPodcastManager() when unconfigured, so early-init calls will produce a
    // .noSubscriptions error rather than crashing.
    let service = OPMLExportService(podcastManager: PlaybackEnvironment.podcastManager)
    do {
      let data = try service.exportSubscriptionsAsXML()
      guard !data.isEmpty else {
        exportErrorMessage = "Export produced an empty file. Please try again."
        showExportError = true
        return
      }
      exportDocument = OPMLFileDocument(data: data)
      isExportPresented = true
    } catch OPMLExportService.Error.noSubscriptions {
      exportErrorMessage = "You have no subscriptions to export."
      showExportError = true
    } catch {
      exportErrorMessage = error.localizedDescription
      showExportError = true
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

// MARK: - OPML File Document

struct OPMLFileDocument: FileDocument {
  static var readableContentTypes: [UTType] {
    // Include the opml-specific UTType when the system knows it; fall back to xml.
    if let opmlType = UTType(filenameExtension: "opml") {
      return [opmlType, .xml]
    }
    return [.xml]
  }

  let data: Data

  init(data: Data) {
    self.data = data
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    self.data = data
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}

// MARK: - Networking bridge

/// Bridges FeedParsing.RSSFeedParser to the Networking.FeedParsing protocol.
///
/// Lives in this file (which imports both `FeedParsing` and `Networking`) so that
/// OPMLSubscriptionAdapter.swift can remain free of the `Networking` import, avoiding
/// the naming conflict between the `FeedParsing` module and `Networking.FeedParsing` protocol.
private struct NetworkingRSSBridge: Networking.FeedParsing, Sendable {
  func parse(data: Data, sourceURL: URL) throws -> Networking.ParsedFeed {
    let podcast = try RSSFeedParser.parseFeed(from: data, feedURL: sourceURL)
    return Networking.ParsedFeed(podcast: podcast)
  }
}

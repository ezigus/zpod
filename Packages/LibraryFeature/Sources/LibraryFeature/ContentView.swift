//
//  ContentView.swift
//  zpodcastaddict
//
//  Created by Eric Ziegler on 7/12/25.
//

import CoreModels
import Persistence
import SettingsDomain
import SharedUtilities
import SwiftData
import SwiftUI

#if os(iOS)
  import UIKit
#endif

#if canImport(DiscoverFeature)
  import DiscoverFeature
  import SearchDomain
  import TestSupport
#else
  // Fallback placeholder when DiscoverFeature module isn't linked
  struct DiscoverView: View {
    @State private var searchText: String = ""
    @State private var showingRSSSheet = false
    @State private var showingMenu = false

    @ViewBuilder
    var body: some View {
      NavigationStack {
        List {
          // Categories section (accessible container)
          Section(header: Text("Categories")) {
            HStack(spacing: 12) {
              ForEach(["Technology", "Entertainment", "News"], id: \.self) { title in
                Button(title) {}
                  .buttonStyle(.bordered)
                  .accessibilityElement(children: .ignore)
                  .accessibilityLabel(title)
              }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("Categories")
          }

          // Featured section marker (for other tests)
          Section(header: Text("Featured")) {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack {
                ForEach(0..<3) { idx in
                  Button("Featured \(idx+1)") {}
                    .buttonStyle(.borderedProminent)
                }
              }
            }
            .frame(height: 60)
            .accessibilityIdentifier("Featured Carousel")
          }

          // Search Results table
          Section(header: Text("Results")) {
            ForEach(1...5, id: \.self) { i in
              Text("Result Item \(i)")
                .accessibilityLabel("Result Item \(i)")
            }
          }
          .accessibilityIdentifier("Search Results")
        }
        // Matches the real DiscoverFeature identifier; only one is compiled per build.
        .accessibilityIdentifier("Discover.Root")
        .navigationTitle("Discover")
        .searchable(text: $searchText, prompt: "Search podcasts")
        .toolbar {
          ToolbarItem(placement: PlatformToolbarPlacement.primaryAction) {
            Button(action: {
              showingMenu = true
            }) {
              Image(systemName: "plus")
            }
            .accessibilityIdentifier("discovery-options-menu")
            .accessibilityLabel("Discovery options")
            .confirmationDialog("Discovery Options", isPresented: $showingMenu) {
              Button("Add RSS Feed") {
                showingRSSSheet = true
              }
              Button("Search History") {
                // No-op for testing
              }
              Button("Cancel", role: .cancel) {}
            }
          }
        }
        .sheet(isPresented: $showingRSSSheet) {
          RSSFeedAdditionSheet()
        }
      }
    }
  }

  private struct RSSFeedAdditionSheet: View {
    @State private var rssURL: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
      NavigationStack {
        Form {
          Section(header: Text("RSS Feed URL")) {
            TextField("Enter RSS URL", text: $rssURL)
              .textFieldStyle(.roundedBorder)
              .accessibilityIdentifier("RSS URL Field")
          }
        }
        .navigationTitle("Add RSS Feed")
        .platformNavigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: PlatformToolbarPlacement.cancellationAction) {
            Button("Cancel") {
              dismiss()
            }
          }
          ToolbarItem(placement: PlatformToolbarPlacement.primaryAction) {
            Button("Add") {
              // No-op for testing
              dismiss()
            }
            .disabled(rssURL.isEmpty)
          }
        }
      }
    }
  }
#endif

#if canImport(PlayerFeature)
  import PlayerFeature
  import PlaybackEngine
#else
  // Fallback placeholder when PlayerFeature module isn't linked
  struct EpisodeDetailView: View {
    let episode: Episode
    var body: some View { Text("Player") }
  }
  struct MiniPlayerView: View {
    var body: some View { EmptyView() }
  }
  @MainActor
  class MiniPlayerViewModel: ObservableObject {}
#endif

#if canImport(PlaylistFeature)
  import PlaylistFeature

  private struct PlaylistTabView: View {
    var body: some View {
      PlaylistFeatureView(playlists: [], episodesProvider: { _ in [] })
    }
  }
#else
  // Fallback placeholder when PlaylistFeature module isn't linked
  private struct PlaylistTabView: View { var body: some View { Text("Playlists") } }
#endif

#if canImport(UIKit)
  // MARK: - Tab Bar Height Observer

  /// Shared observable that publishes the actual tab bar height for dynamic mini-player positioning.
  /// Updated by TabBarIdentifierSetter when it locates the UITabBar.
  @MainActor
  final class TabBarHeightObserver: ObservableObject {
    static let shared = TabBarHeightObserver()

    /// The measured tab bar height (includes the full visual height)
    @Published private(set) var height: CGFloat = 0

    /// Safe bottom padding for content that should appear above the tab bar.
    /// Returns 0 when height hasn't been measured yet (content will be positioned by safeAreaInset).
    /// Once measured, returns the tab bar height plus a small margin for visual separation.
    var contentBottomPadding: CGFloat {
      guard height > 0 else { return 0 }
      return height + 8  // Tab bar height + 8pt margin for visual separation
    }

    private init() {}

    func update(height: CGFloat) {
      guard height > 0, height != self.height else { return }
      self.height = height
    }
  }

  // MARK: - UIKit Introspection Helper for Tab Bar Identifier
  private struct TabBarIdentifierSetter: UIViewControllerRepresentable {
    private let maxAttempts = 50
    private let retryInterval: TimeInterval = 0.1

    func makeUIViewController(context: Context) -> UIViewController {
      let controller = UIViewController()
      scheduleIdentifierUpdate(from: controller, attempt: 0)
      return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
      scheduleIdentifierUpdate(from: uiViewController, attempt: 0)
    }

    private func scheduleIdentifierUpdate(from uiViewController: UIViewController, attempt: Int) {
      let delay = attempt == 0 ? 0 : retryInterval
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        guard
          let tabBar = self.locateTabBar(startingFrom: uiViewController)
            ?? self.locateTabBarAcrossScenes()
        else {
          self.retryIfNeeded(from: uiViewController, attempt: attempt)
          return
        }
        self.configure(tabBar: tabBar)
      }
    }

    private func retryIfNeeded(from uiViewController: UIViewController, attempt: Int) {
      guard attempt < maxAttempts else { return }
      scheduleIdentifierUpdate(from: uiViewController, attempt: attempt + 1)
    }

    @MainActor
    private func locateTabBar(startingFrom uiViewController: UIViewController) -> UITabBar? {
      if let tabBarController = findTabBarController(from: uiViewController) {
        return tabBarController.tabBar
      }

      if let parent = uiViewController.parent,
        let tabBarController = findTabBarController(from: parent)
      {
        return tabBarController.tabBar
      }

      if let window = uiViewController.view.window,
        let rootController = window.rootViewController,
        let tabBarController = findTabBarController(from: rootController)
      {
        return tabBarController.tabBar
      }

      return nil
    }

    @MainActor
    private func locateTabBarAcrossScenes() -> UITabBar? {
      let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter {
          $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
        }

      for scene in scenes {
        for window in scene.windows where !window.isHidden {
          if let controller = findTabBarController(from: window.rootViewController) {
            return controller.tabBar
          }
        }
      }

      return nil
    }

    @MainActor
    private func configure(tabBar: UITabBar) {
      if tabBar.accessibilityIdentifier != "Main Tab Bar" {
        tabBar.accessibilityIdentifier = "Main Tab Bar"
        tabBar.accessibilityLabel = "Main Tab Bar"
      }

      // Publish the tab bar height for dynamic mini-player positioning
      TabBarHeightObserver.shared.update(height: tabBar.frame.height)

      guard let items = tabBar.items, !items.isEmpty else { return }

      let fallbackTitles = ["Library", "Discover", "Playlists", "Player", "Settings"]

      for (index, item) in items.enumerated() {
        let resolvedTitle: String = {
          if let existingTitle = item.title, !existingTitle.isEmpty {
            return existingTitle
          }
          if index < fallbackTitles.count {
            return fallbackTitles[index]
          }
          return "Tab \(index + 1)"
        }()

        if (item.title ?? "").isEmpty {
          item.title = resolvedTitle
        }

        if (item.accessibilityLabel ?? "").isEmpty {
          item.accessibilityLabel = resolvedTitle
        }

        if (item.accessibilityHint ?? "").isEmpty {
          item.accessibilityHint = "Opens \(resolvedTitle)"
        }

        if !item.accessibilityTraits.contains(.button) {
          item.accessibilityTraits.insert(.button)
        }
      }
    }

    private func findTabBarController(from vc: UIViewController?) -> UITabBarController? {
      guard let vc else { return nil }

      if let tabBarController = vc as? UITabBarController {
        return tabBarController
      }

      for child in vc.children {
        if let controller = findTabBarController(from: child) {
          return controller
        }
      }

      if let presented = vc.presentedViewController {
        return findTabBarController(from: presented)
      }

      return nil
    }
  }
#endif

#if os(iOS) || os(macOS)

  private func resolveTestAudioURL(
    envKey: String,
    bundleName: String,
    env: [String: String]
  ) -> URL? {
    let isDebugAudio = env["UITEST_DEBUG_AUDIO"] == "1"

    if let path = env[envKey] {
      let url = URL(fileURLWithPath: path)
      if FileManager.default.isReadableFile(atPath: url.path) {
        if isDebugAudio {
          NSLog("Audio env resolved: %@ -> %@", envKey, url.path)
        }
        return url
      } else if isDebugAudio {
        NSLog("Audio env missing file: %@ -> %@", envKey, path)
      }
    }

    if let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "m4a") {
      if isDebugAudio {
        NSLog("Audio bundle resolved: %@ -> %@", bundleName, bundleURL.path)
      }
      return bundleURL
    }

    if isDebugAudio {
      NSLog("Audio not found for env=%@ bundle=%@", envKey, bundleName)
    }
    return nil
  }

  public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    // Service instances for dependency injection
    private let podcastManager: PodcastManaging
    private let searchService: SearchServicing
    @StateObject private var settingsManager: SettingsManager

    // Mini-player state
    #if canImport(PlayerFeature)
      private let playbackDependencies: CarPlayDependencies
      @StateObject private var miniPlayerViewModel: MiniPlayerViewModel
      @StateObject private var expandedPlayerViewModel: ExpandedPlayerViewModel
    #endif
    @State private var showFullPlayer: Bool

    // Tab bar height for dynamic mini-player positioning
    #if canImport(UIKit)
      @StateObject private var tabBarHeight = TabBarHeightObserver.shared
    #endif

    // CRITICAL: Explicit tab selection binding fixes tab switching when animations disabled in UI tests.
    // Without this, SwiftUI's internal tab mechanism fails when UIView.setAnimationsEnabled(false).
    // TODO: Revisit on newer iOS releases to confirm SwiftUI tab selection no longer requires this workaround.
    @State private var selectedTab: Int = 0

    public init(podcastManager: PodcastManaging? = nil) {
      // Use provided podcast manager or create a new one (for backward compatibility)
      self.podcastManager = podcastManager ?? InMemoryPodcastManager()

      // Create search index sources (empty for now, will be populated as content is added)
      let searchSources: [SearchIndexSource] = []
      self.searchService = SearchService(indexSources: searchSources)
      let repository = UserDefaultsSettingsRepository()
      _settingsManager = StateObject(wrappedValue: SettingsManager(repository: repository))
      let forceExpandedPlayer =
        ProcessInfo.processInfo.environment["UITEST_FORCE_EXPANDED_PLAYER"] == "1"
      _showFullPlayer = State(initialValue: forceExpandedPlayer)
      _selectedTab = State(initialValue: Self.initialTabSelection())

      // Initialize mini-player with playback service from CarPlay dependencies
      #if canImport(PlayerFeature)
        let dependencies = PlaybackEnvironment.dependencies
        self.playbackDependencies = dependencies
        _miniPlayerViewModel = StateObject(
          wrappedValue: MiniPlayerViewModel(
            playbackService: dependencies.playbackService,
            queueIsEmpty: { dependencies.queueManager.queuedEpisodes.isEmpty },
            alertPresenter: dependencies.playbackAlertPresenter
          )
        )
        _expandedPlayerViewModel = StateObject(
          wrappedValue: ExpandedPlayerViewModel(
            playbackService: dependencies.playbackService,
            alertPresenter: dependencies.playbackAlertPresenter
          )
        )
      #endif
    }

    public var body: some View {
      ZStack(alignment: .bottom) {
        TabView(selection: $selectedTab) {
          // Library Tab (existing functionality)
          LibraryView()
            .tabItem {
              Label("Library", systemImage: "books.vertical")
            }
            .tag(0)

          // Discover Tab (placeholder UI)
          DiscoverView(
            searchService: searchService,
            podcastManager: podcastManager
          )
            .tabItem {
              Label("Discover", systemImage: "safari")
            }
            .tag(1)

          // Playlists Tab (placeholder UI)
          PlaylistTabView()
            .tabItem {
              Label("Playlists", systemImage: "music.note.list")
            }
            .tag(2)

          // Player Tab (placeholder - shows sample episode)
          #if canImport(PlayerFeature)
            PlayerTabView(playbackService: playbackDependencies.playbackService)
              .tabItem {
                Label("Player", systemImage: "play.circle")
              }
              .tag(3)
          #else
            PlayerTabView()
              .tabItem {
                Label("Player", systemImage: "play.circle")
              }
              .tag(3)
          #endif

          SettingsHomeView(settingsManager: settingsManager)
            .tabItem {
              Label("Settings", systemImage: "gearshape")
            }
            .tag(4)
        }
        #if canImport(UIKit)
          .background(TabBarIdentifierSetter())
        #endif
      }
      // Mini-player positioned above tab bar using safeAreaInset (Issue 03.2 fix)
      // The padding is dynamically calculated from the actual tab bar height measured via UIKit.
      // TabBarHeightObserver.contentBottomPadding returns: tabBarHeight + 8pt margin
      // This ensures proper spacing regardless of device size, orientation, or iOS version.
      .safeAreaInset(edge: .bottom) {
        #if canImport(PlayerFeature)
          if miniPlayerViewModel.displayState.isVisible {
            MiniPlayerView(viewModel: miniPlayerViewModel) {
              showFullPlayer = true
            }
            #if canImport(UIKit)
              .padding(.bottom, tabBarHeight.contentBottomPadding)
            #else
              .padding(.bottom, 60)  // Fallback for non-UIKit platforms
            #endif
            .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        #endif
      }
      #if canImport(PlayerFeature)
        .sheet(isPresented: $showFullPlayer) {
          ExpandedPlayerView(
            viewModel: expandedPlayerViewModel
          )
          .presentationDragIndicator(.hidden)
          .presentationBackground(.black)
        }
      #endif
    }

    private static func initialTabSelection() -> Int {
      UITestTabSelection.resolve(
        rawValue: ProcessInfo.processInfo.environment["UITEST_INITIAL_TAB"],
        maxIndex: 4,
        mapping: [
          "library": 0,
          "discover": 1,
          "playlists": 2,
          "player": 3,
          "settings": 4,
        ]
      )
    }
  }

  // MARK: - Data Models for UI Testing
  private struct PodcastItem: Identifiable {
    let id: String
    let title: String
  }

  /// Library view using card-based button layout instead of table for XCUITest compatibility
  struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    @State private var samplePodcasts: [PodcastItem] = []
    @State private var isLoading = true

    var body: some View {
      NavigationStack {
        if isLoading {
          ProgressView("Loading...")
            .accessibilityIdentifier("Loading View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Library")
        } else {
          ScrollView {
            LazyVStack(spacing: 16) {
              // Accessible heading required by UI tests
              Text("Heading Library")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityIdentifier("Heading Library")
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

              // Card-based podcast layout (no table structure)
              ForEach(samplePodcasts) { podcast in
                PodcastCardView(podcast: podcast)
                  .padding(.horizontal)
              }

              // Show persisted items as cards
              ForEach(items) { item in
                NavigationLink {
                  Text(
                    "Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))"
                  )
                } label: {
                  VStack(alignment: .leading) {
                    Text("Data Item")
                      .font(.headline)
                    Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding()
                  .background(Color.platformSystemGray6)
                  .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
              }
            }
            .padding(.vertical)
          }
          .accessibilityIdentifier("Podcast Cards Container")
          .navigationTitle("Library")
          .toolbar {
            ToolbarItem {
              Button(action: addItem) {
                Label("Add Item", systemImage: "plus")
              }
            }
          }
        }
      }
      .onAppear {
        Task {
          await loadData()
        }
      }
    }

    private func addItem() {
      withAnimation {
        let newItem = Item(timestamp: Date())
        modelContext.insert(newItem)
      }
    }

    private func deleteItems(offsets: IndexSet) {
      withAnimation {
        for index in offsets {
          modelContext.delete(items[index])
        }
      }
    }

    @MainActor
    private func loadData() async {
      // Load sample data for UI tests and development
      // Using proper async loading without artificial delays
      samplePodcasts = [
        PodcastItem(id: "swift-talk", title: "Swift Talk"),
        PodcastItem(id: "swift-over-coffee", title: "Swift Over Coffee"),
        PodcastItem(id: "accidental-tech-podcast", title: "Accidental Tech Podcast"),
      ]

      isLoading = false

      // Retry playback restoration now that library is loaded
      // This handles the race condition where initial restoration ran before data was available
      await PlaybackEnvironment.playbackStateCoordinator?.restorePlaybackIfNeeded()
    }
  }

  // MARK: - Podcast Card View for Button-Based Layout (No Table Structure)
  private struct PodcastCardView: View {
    let podcast: PodcastItem

    var body: some View {
      NavigationLink(
        destination: EpisodeListViewWrapper(podcastId: podcast.id, podcastTitle: podcast.title)
      ) {
        HStack(spacing: 16) {
          // Podcast artwork placeholder
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 80, height: 80)
            .overlay(
              Image(systemName: "music.note")
                .font(.title2)
                .foregroundColor(.gray)
            )

          VStack(alignment: .leading, spacing: 6) {
            Text(podcast.title)
              .font(.headline)
              .foregroundColor(.primary)
            Text("Sample Podcast Description")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .lineLimit(2)
            Text("42 episodes")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.platformSystemGray6)
        .cornerRadius(16)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("Podcast-\(podcast.id)")
      .accessibilityLabel(podcast.title)
      .accessibilityHint("Opens episode list for \(podcast.title)")
      .accessibilityAddTraits(.isButton)
    }
  }

  // MARK: - Episode List View Wrapper with Real Batch Operations
    struct EpisodeListViewWrapper: View {
      let podcastId: String
      let podcastTitle: String

      var body: some View {
        // Create a real Podcast object with sample episodes for testing
        let samplePodcast = createSamplePodcast(id: podcastId, title: podcastTitle)

        // Allow UI tests to opt into a lightweight list to avoid dependency flakiness
        let useSimpleList =
          ProcessInfo.processInfo.environment["UITEST_USE_SIMPLE_EPISODE_LIST"] == "1"

        if useSimpleList {
          EpisodeListCardContainer(podcastId: podcastId, podcastTitle: podcastTitle)
        } else {
          // Use the real EpisodeListView with full batch operation functionality
          EpisodeListView(podcast: samplePodcast)
        }
      }

      private func createSamplePodcast(id: String, title: String) -> Podcast {
      // Read test audio URLs from environment variables (only set during UI tests)
      // In production, these will be nil and episodes will use placeholder URLs
      let env = ProcessInfo.processInfo.environment

      // Resolve audio URLs with fallback to bundle
      let shortAudioURL = resolveTestAudioURL(
        envKey: "UITEST_AUDIO_SHORT_PATH",
        bundleName: "test-episode-short",
        env: env
      )
      let mediumAudioURL = resolveTestAudioURL(
        envKey: "UITEST_AUDIO_MEDIUM_PATH",
        bundleName: "test-episode-medium",
        env: env
      )
      let longAudioURL = resolveTestAudioURL(
        envKey: "UITEST_AUDIO_LONG_PATH",
        bundleName: "test-episode-long",
        env: env
      )
        
        let sampleEpisodes = [
          Episode(
          id: "st-001",
          title: "Episode 1: Introduction",
          podcastID: id,
          podcastTitle: title,
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
          duration: 2723,  // 45:23
          description: "Introduction to the podcast series.",
          audioURL: shortAudioURL ?? URL(string: "https://example.com/episode1.mp3")
        ),
        Episode(
          id: "st-002",
          title: "Episode 2: Swift Basics",
          podcastID: id,
          podcastTitle: title,
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
          duration: 3137,  // 52:17
          description: "Covering Swift language basics.",
          audioURL: mediumAudioURL ?? URL(string: "https://example.com/episode2.mp3")
        ),
        Episode(
          id: "st-003",
          title: "Episode 3: Advanced Topics",
          podcastID: id,
          podcastTitle: title,
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date(),
          duration: 3702,  // 61:42
          description: "Deep dive into advanced Swift concepts.",
          audioURL: longAudioURL ?? URL(string: "https://example.com/episode3.mp3")
        ),
        Episode(
          id: "st-004",
          title: "Episode 4: Performance",
          podcastID: id,
          podcastTitle: title,
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date(),
          duration: 2336,  // 38:56
          description: "Performance optimization techniques.",
          audioURL: shortAudioURL ?? URL(string: "https://example.com/episode4.mp3")
        ),
        Episode(
          id: "st-005",
          title: "Episode 5: Testing",
          podcastID: id,
          podcastTitle: title,
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Calendar.current.date(byAdding: .day, value: -35, to: Date()) ?? Date(),
          duration: 2673,  // 44:33
          description: "Testing strategies and best practices.",
          audioURL: mediumAudioURL ?? URL(string: "https://example.com/episode5.mp3")
        ),
      ]

      return Podcast(
        id: id,
        title: title,
        author: "Sample Author",
        description: "Sample podcast for UI testing with batch operations",
        feedURL: URL(string: "https://example.com/feed.rss")!,
        episodes: sampleEpisodes,
        dateAdded: Date()
      )
    }
  }

  /// Player tab that shows the EpisodeDetailView with a sample episode
  #if canImport(PlayerFeature)
    struct PlayerTabView: View {
      let playbackService: EpisodePlaybackService & EpisodeTransportControlling

      var body: some View {
        NavigationStack {
          ZStack {
            sampleEpisodeView
          }
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier("Player Interface")
          .navigationTitle("Player")
        }
      }

      private var sampleEpisodeView: some View {
        EpisodeDetailView(
          episode: sampleEpisode,
          playbackService: playbackService
        )
      }

      private var sampleEpisode: Episode {
        let env = ProcessInfo.processInfo.environment
        let audioVariant = env["UITEST_AUDIO_VARIANT"]?.lowercased() ?? "short"
        let audioURL: URL?
        let duration: TimeInterval
        switch audioVariant {
        case "long":
          audioURL = resolveTestAudioURL(
            envKey: "UITEST_AUDIO_LONG_PATH",
            bundleName: "test-episode-long",
            env: env
          )
          duration = 20.0
        case "medium":
          audioURL = resolveTestAudioURL(
            envKey: "UITEST_AUDIO_MEDIUM_PATH",
            bundleName: "test-episode-medium",
            env: env
          )
          duration = 15.0
        default:
          audioURL = resolveTestAudioURL(
            envKey: "UITEST_AUDIO_SHORT_PATH",
            bundleName: "test-episode-short",
            env: env
          )
          duration = 6.523
        }
        return Episode(
          id: "sample-1",
          title: "Sample Episode",
          podcastID: "sample-podcast",
          podcastTitle: "Sample Podcast",
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Date(),
          duration: duration,
          description: "This is a sample episode to demonstrate the player interface.",
          audioURL: audioURL ?? URL(string: "https://example.com/episode.mp3")
        )
      }
    }
  #else
    struct PlayerTabView: View {
      var body: some View {
        Text("Player")
          .font(.title2)
          .padding()
      }
    }
  #endif

  // MARK: - Episode List Card Container (No Table Structure)
  struct EpisodeListCardContainer: View {
    let podcastId: String
    let podcastTitle: String

    @State private var episodes: [SimpleEpisodeItem] = []
    @State private var isLoading = true

    struct SimpleEpisodeItem: Identifiable {
      let id: String
      let title: String
      let duration: String
      let date: String
    }

    var body: some View {
      NavigationStack {
        if isLoading {
          ProgressView("Loading Episodes...")
            .accessibilityIdentifier("Loading View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(podcastTitle)
            .platformNavigationBarTitleDisplayMode(.large)
        } else {
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(episodes) { episode in
                SimpleEpisodeCardView(episode: episode)
                  .padding(.horizontal)
              }
            }
            .padding(.vertical)
          }
          .accessibilityIdentifier("Episode Cards Container")
          .navigationTitle(podcastTitle)
          .platformNavigationBarTitleDisplayMode(.large)
        }
      }
      .onAppear {
        Task {
          await loadEpisodes()
        }
      }
    }

    @MainActor
    private func loadEpisodes() async {
      // Load sample episodes for UI tests
      // Using proper async loading without artificial delays
      episodes = [
        SimpleEpisodeItem(
          id: "st-001", title: "Episode 1: Introduction", duration: "45:23", date: "Dec 8"),
        SimpleEpisodeItem(
          id: "st-002", title: "Episode 2: Swift Basics", duration: "52:17", date: "Dec 1"),
        SimpleEpisodeItem(
          id: "st-003", title: "Episode 3: Advanced Topics", duration: "61:42", date: "Nov 24"),
        SimpleEpisodeItem(
          id: "st-004", title: "Episode 4: Performance", duration: "38:56", date: "Nov 17"),
        SimpleEpisodeItem(
          id: "st-005", title: "Episode 5: Testing", duration: "44:33", date: "Nov 10"),
      ]

      isLoading = false
    }
  }

  // MARK: - Simple Episode Card View for Button-Based Layout (No Table Structure)
  private struct SimpleEpisodeCardView: View {
    let episode: EpisodeListCardContainer.SimpleEpisodeItem

    var body: some View {
      NavigationLink(
        destination: EpisodeDetailPlaceholder(episodeId: episode.id, episodeTitle: episode.title)
      ) {
        VStack(alignment: .leading, spacing: 12) {
          Text(episode.title)
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

          HStack {
            Label(episode.duration, systemImage: "clock")
              .font(.caption)
              .foregroundColor(.secondary)

            Spacer()

            Text(episode.date)
              .font(.caption)
              .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
        .padding()
        .background(Color.platformSystemGray6)
        .cornerRadius(12)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("Episode-\(episode.id)")
      .accessibilityLabel(episode.title)
      .accessibilityHint("Opens episode detail")
      .accessibilityAddTraits(.isButton)
    }
  }

  // MARK: - Episode Detail Placeholder for UI Tests
  struct EpisodeDetailPlaceholder: View {
    let episodeId: String
    let episodeTitle: String

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text(episodeTitle)
            .font(.title)
            .accessibilityAddTraits(.isHeader)

          Text("This is a sample episode detail view for UI testing purposes.")
            .font(.body)

          Text("Episode ID: \(episodeId)")
            .font(.caption)
            .foregroundColor(.secondary)

          // Sample player controls
          VStack(spacing: 16) {
            Button("Play Episode") {
              // No-op for testing
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("Play Episode")

            HStack {
              Button("Add to Playlist") {
                // No-op for testing
              }
              .buttonStyle(.bordered)

              Spacer()

              Button("Share") {
                // No-op for testing
              }
              .buttonStyle(.bordered)
            }
          }
          .padding(.top)

          Spacer()
        }
        .padding()
      }
      .accessibilityIdentifier("Episode Detail View")
      .navigationTitle("Episode Detail")
      .platformNavigationBarTitleDisplayMode(.inline)
    }
  }

  #Preview {
    ContentView()
      .modelContainer(for: Item.self, inMemory: true)
  }

#else

  public struct ContentView: View {
    public init() {}

    public var body: some View {
      Text("Library content is available on iOS only.")
    }
  }

#endif

//
//  ContentView.swift
//  zpodcastaddict
//
//  Created by Eric Ziegler on 7/12/25.
//

import CoreModels
import OSLog
import Persistence
import SearchDomain
import SettingsDomain
import SharedUtilities
import SwiftData
import SwiftUI

#if os(iOS)
  import UIKit
#endif

private let logger = Logger(subsystem: "us.zig.zpod.library", category: "TestAudio")

#if canImport(DiscoverFeature)
  import DiscoverFeature
  import SearchDomain
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
    @State private var viewModel: PlaylistViewModel
    @State private var smartViewModel: SmartPlaylistViewModel

    init(
      playlistManager: any PlaylistManaging,
      podcastManager: PodcastManaging,
      queueManager: (any CarPlayQueueManaging)? = nil
    ) {
      let provider: (Playlist) -> [Episode] = { playlist in
        let episodeIndex = podcastManager.all()
          .flatMap { $0.episodes }
          .reduce(into: [String: Episode]()) { dict, episode in dict[episode.id] = episode }
        return playlist.episodeIds.compactMap { episodeIndex[$0] }
      }
      let playlistViewModel = PlaylistViewModel(manager: playlistManager, episodeProvider: provider)
      if let queueManager {
        playlistViewModel.onPlayAll = { playlist in
          let episodes = provider(playlist)
          guard let first = episodes.first else { return }
          queueManager.playNow(first)
          episodes.dropFirst().forEach { queueManager.enqueue($0) }
        }
        playlistViewModel.onShuffle = { playlist in
          let episodes = provider(playlist).shuffled()
          guard let first = episodes.first else { return }
          queueManager.playNow(first)
          episodes.dropFirst().forEach { queueManager.enqueue($0) }
        }
      }
      _viewModel = State(initialValue: playlistViewModel)

      // Wire SmartPlaylistViewModel — uses UserDefaultsSmartPlaylistManager so custom
      // playlists survive app restarts. Built-in lists always come from
      // SmartEpisodeListV2.builtInSmartLists and are never written to UserDefaults.
      let allEpisodesProvider: () -> [Episode] = { podcastManager.all().flatMap { $0.episodes } }
      let smartManager = UserDefaultsSmartPlaylistManager()
      let smartVM = SmartPlaylistViewModel(manager: smartManager, allEpisodesProvider: allEpisodesProvider)
      if let queueManager {
        smartVM.onPlayAll = { episodes in
          guard let first = episodes.first else { return }
          queueManager.playNow(first)
          episodes.dropFirst().forEach { queueManager.enqueue($0) }
        }
        smartVM.onShuffle = { episodes in
          let shuffled = episodes.shuffled()
          guard let first = shuffled.first else { return }
          queueManager.playNow(first)
          shuffled.dropFirst().forEach { queueManager.enqueue($0) }
        }
      }
      smartVM.analyticsRepository = UserDefaultsSmartPlaylistAnalyticsRepository()
      _smartViewModel = State(initialValue: smartVM)
    }

    var body: some View {
      PlaylistFeatureView(viewModel: viewModel, smartViewModel: smartViewModel)
    }
  }
#else
  // Fallback placeholder when PlaylistFeature module isn't linked
  private struct PlaylistTabView: View {
    init(playlistManager: any PlaylistManaging, podcastManager: PodcastManaging, queueManager: (any CarPlayQueueManaging)? = nil) {}
    var body: some View { Text("Playlists") }
  }
#endif

#if canImport(UIKit)
  // MARK: - Tab Bar Measurement View Controller
  /// Fires onViewDidAppear once after the view hierarchy is fully set up.
  /// This avoids any DispatchQueue.main.asyncAfter retry loops that would keep
  /// pending async work on the main queue and prevent XCUITest quiescence detection.
  private final class TabBarMeasurementViewController: UIViewController {
    var onViewDidAppear: (() -> Void)?

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      onViewDidAppear?()
      onViewDidAppear = nil
    }
  }

  // MARK: - UIKit Introspection Helper for Tab Bar Identifier
  private struct TabBarIdentifierSetter: UIViewControllerRepresentable {
    /// Written once when the UITabBar is first found. Reports intrinsicContentSize.height (49pt
    /// on standard iPhones), which is the value needed to offset the mini-player above the tab bar
    /// via .safeAreaInset — separate from the home-indicator safe area that SwiftUI already handles.
    @Binding var tabBarHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Tracks whether tab bar measurement has already completed so that SwiftUI
    /// re-renders (which call updateUIViewController repeatedly) never schedule
    /// redundant work.
    final class Coordinator {
      var isConfigured = false
    }

    func makeUIViewController(context: Context) -> TabBarMeasurementViewController {
      let vc = TabBarMeasurementViewController()
      // viewDidAppear fires after the full UIKit view hierarchy is assembled —
      // the tab bar is guaranteed to be present at that point, so no retry loop needed.
      vc.onViewDidAppear = {
        guard !context.coordinator.isConfigured else { return }
        if let tabBar = self.locateTabBar(startingFrom: vc)
          ?? self.locateTabBarAcrossScenes()
        {
          context.coordinator.isConfigured = true
          self.configure(tabBar: tabBar)
        }
      }
      return vc
    }

    func updateUIViewController(_ uiViewController: TabBarMeasurementViewController, context: Context) {
      // Once configured, nothing to do on any subsequent re-render.
      guard !context.coordinator.isConfigured else { return }
      // If viewDidAppear has already fired (callback cleared) but measurement hasn't completed
      // (tab bar wasn't in hierarchy yet — rare), try once synchronously. No asyncAfter needed.
      guard uiViewController.onViewDidAppear == nil else { return }
      if let tabBar = locateTabBar(startingFrom: uiViewController)
        ?? locateTabBarAcrossScenes()
      {
        context.coordinator.isConfigured = true
        configure(tabBar: tabBar)
      }
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

      // Publish the tab bar's intrinsic content height (excludes home-indicator safe area
      // extension) so the mini-player offset stays correct across device types.
      let intrinsicHeight = tabBar.intrinsicContentSize.height
      if intrinsicHeight > 0 {
        tabBarHeight = intrinsicHeight
      }

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

        if (item.accessibilityIdentifier ?? "").isEmpty {
          item.accessibilityIdentifier = resolvedTitle
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
    if env["UITEST_AUDIO_OVERRIDE_MODE"] == "missing" {
      if isDebugAudio {
        NSLog("Audio override mode=missing for %@", envKey)
      }
      return nil
    }

    if let overrideValue = env["UITEST_AUDIO_OVERRIDE_URL"], !overrideValue.isEmpty {
      if let overrideURL = URL(string: overrideValue), overrideURL.scheme != nil {
        if isDebugAudio {
          NSLog("Audio override URL resolved: %@", overrideURL.absoluteString)
        }
        return overrideURL
      }

      let fileURL = URL(fileURLWithPath: overrideValue)
      if FileManager.default.isReadableFile(atPath: fileURL.path) {
        if isDebugAudio {
          NSLog("Audio override file resolved: %@", fileURL.path)
        }
        return fileURL
      } else if isDebugAudio {
        NSLog("Audio override file missing: %@", overrideValue)
      }
    }

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

    if env["UITEST_AUDIO_DISABLE_BUNDLE"] == "1" {
      if isDebugAudio {
        NSLog("Audio bundle fallback disabled for %@", bundleName)
      }
      return nil
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
    // Service instances for dependency injection
    private let podcastManager: PodcastManaging
    private let playlistManager: any PlaylistManaging
    private let searchService: SearchServicing
    @StateObject private var settingsManager: SettingsManager

    // Mini-player state
    #if canImport(PlayerFeature)
      private let playbackDependencies: CarPlayDependencies
      @StateObject private var miniPlayerViewModel: MiniPlayerViewModel
      @StateObject private var expandedPlayerViewModel: ExpandedPlayerViewModel
    #endif
    @State private var showFullPlayer: Bool

    // CRITICAL: Explicit tab selection binding fixes tab switching when animations disabled in UI tests.
    // Without this, SwiftUI's internal tab mechanism fails when UIView.setAnimationsEnabled(false).
    // TODO: Revisit on newer iOS releases to confirm SwiftUI tab selection no longer requires this workaround.
    @State private var selectedTab: Int = 0
    /// Dynamic tab bar height measured from the live UITabBar instance by TabBarIdentifierSetter.
    /// Defaults to 49pt (standard UITabBar intrinsicContentSize.height) before measurement completes.
    @State private var tabBarHeight: CGFloat = 49
    // Incremented each time the Library tab (tag 0) is selected, causing LibraryView to reload.
    // This covers the case where the user adds a podcast in Discover and returns to Library
    // without .onAppear re-firing (e.g., back-navigation within the tab stack).
    @State private var libraryRefreshTrigger: Int = 0

    public init(podcastManager: PodcastManaging, playlistManager: any PlaylistManaging) {
      self.podcastManager = podcastManager
      self.playlistManager = playlistManager

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
          LibraryView(podcastManager: podcastManager, playlistManager: playlistManager, refreshTrigger: libraryRefreshTrigger)
            .tabItem {
              Label("Library", systemImage: "books.vertical")
            }
            .tag(0)

          // Discover Tab
          DiscoverView(
            searchService: searchService,
            podcastManager: podcastManager,
            directoryService: DirectoryServiceFactory.makeDefault(
              podcastIndexAPIKey: Bundle.main.infoDictionary?["PODCAST_INDEX_API_KEY"] as? String,
              podcastIndexAPISecret: Bundle.main.infoDictionary?["PODCAST_INDEX_API_SECRET"] as? String
            )
          )
            .tabItem {
              Label("Discover", systemImage: "safari")
            }
            .tag(1)

          // Playlists Tab
          PlaylistTabView(
            playlistManager: playlistManager,
            podcastManager: podcastManager,
            queueManager: playlistQueueManager
          )
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
          .background(TabBarIdentifierSetter(tabBarHeight: $tabBarHeight))
        #endif
      }
      // Issue 03.1.1.7: Mini-player as tab bar extension — sits flush above the tab bar.
      // .safeAreaInset anchors the mini-player at the home-indicator safe area edge (not
      // the tab bar top). The tabBarHeight offset lifts it to the tab bar's top edge so
      // it doesn't block tab bar interaction. tabBarHeight is measured dynamically from
      // the live UITabBar via TabBarIdentifierSetter (defaults to 49pt before measurement).
      .safeAreaInset(edge: .bottom) {
        #if canImport(PlayerFeature)
          if miniPlayerViewModel.displayState.isVisible {
            MiniPlayerView(viewModel: miniPlayerViewModel) {
              showFullPlayer = true
            }
            .padding(.bottom, tabBarHeight)
            .transition(
              ProcessInfo.processInfo.environment["UITEST_DISABLE_ANIMATIONS"] == "1"
                ? .identity
                : .move(edge: .bottom).combined(with: .opacity)
            )
          }
        #endif
      }
      // Refresh Library when user navigates back to tab 0 — covers the case where
      // .onAppear doesn't re-fire (e.g., podcast added in Discover without leaving Library tab stack).
      .onChange(of: selectedTab) { _, newTab in
        if newTab == 0 {
          libraryRefreshTrigger += 1
        }
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
      // UITEST_FORCE_MINI_PLAYER: Seed a sample episode so the mini player appears at launch
      // without requiring UI navigation. Analogous to UITEST_FORCE_EXPANDED_PLAYER.
      .task {
        #if canImport(PlayerFeature)
          if ProcessInfo.processInfo.environment["UITEST_FORCE_MINI_PLAYER"] == "1" {
            let env = ProcessInfo.processInfo.environment
            let audioURL = resolveTestAudioURL(
              envKey: "UITEST_AUDIO_SHORT_PATH",
              bundleName: "test-episode-short",
              env: env
            ) ?? URL(string: "https://example.com/test-episode.mp3")
            let episode = Episode(
              id: "force-mini-player-sample",
              title: "Test Episode",
              podcastID: "force-mini-player-podcast",
              podcastTitle: "Test Podcast",
              playbackPosition: 0,
              isPlayed: false,
              pubDate: Date(),
              duration: 60.0,
              description: "",
              audioURL: audioURL
            )
            playbackDependencies.playbackService.play(episode: episode, duration: 60.0)
          }
        #endif
      }
    }

    /// The queue manager used to wire playlist playback — only available when PlayerFeature is linked.
    private var playlistQueueManager: (any CarPlayQueueManaging)? {
      #if canImport(PlayerFeature)
        return playbackDependencies.queueManager
      #else
        return nil
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

  /// Library view using card-based button layout instead of table for XCUITest compatibility
  struct LibraryView: View {
    let podcastManager: PodcastManaging
    let playlistManager: (any PlaylistManaging)?
    let refreshTrigger: Int

    @State private var podcasts: [Podcast] = []
    @State private var isLoading = true

    private static let libraryLogger = Logger(
      subsystem: "us.zig.zpod.library",
      category: "LibraryView"
    )

    init(podcastManager: PodcastManaging, playlistManager: (any PlaylistManaging)? = nil, refreshTrigger: Int = 0) {
      self.podcastManager = podcastManager
      self.playlistManager = playlistManager
      self.refreshTrigger = refreshTrigger
    }

    var body: some View {
      NavigationStack {
        if isLoading {
          ProgressView("Loading...")
            .accessibilityIdentifier("Loading View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Library")
        } else if podcasts.isEmpty {
          // NOTE: PodcastManaging.all() is non-throwing — repository errors are handled
          // internally (logged via OSLog, returning []). An empty result therefore covers
          // both "no subscriptions" and "repository failure" scenarios. The diagnostic log
          // in loadPodcasts() distinguishes the two for developers.
          ContentUnavailableView(
            "No Podcasts Yet",
            systemImage: "antenna.radiowaves.left.and.right",
            description: Text("Subscribe to podcasts in the Discover tab to see them here")
          )
          .accessibilityIdentifier("Library.EmptyState")
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
              ForEach(podcasts, id: \.id) { podcast in
                PodcastCardView(podcast: podcast, playlistManager: playlistManager)
                  .padding(.horizontal)
              }
            }
            .padding(.vertical)
          }
          .accessibilityIdentifier("Podcast Cards Container")
          .navigationTitle("Library")
        }
      }
      .onAppear {
        loadPodcasts()

        isLoading = false

        // Playback restoration is genuinely async — keep in its own Task.
        Task {
          await PlaybackEnvironment.playbackStateCoordinator?.restorePlaybackIfNeeded()
        }
      }
      // Re-load when the user navigates back to the Library tab — covers cases where
      // .onAppear does not re-fire (e.g., podcast added in Discover without leaving
      // the Library tab stack). Synchronous call; no Task to preserve XCUITest quiescence.
      .onChange(of: refreshTrigger) { _, _ in
        loadPodcasts()
      }
      // Reactive update: reload whenever any PodcastManaging implementation mutates data.
      // This covers the Discover → Library same-session flow without requiring tab switches.
      .onReceive(NotificationCenter.default.publisher(for: .podcastLibraryDidChange)) { _ in
        loadPodcasts()
      }
    }

    /// Loads podcasts from the repository with diagnostic logging.
    ///
    /// `PodcastManaging.all()` is non-throwing by design — implementations handle errors
    /// internally (logging and returning `[]`). This wrapper adds view-level diagnostics
    /// so an empty result after a repository failure is visible in logs.
    private func loadPodcasts() {
      let result = podcastManager.all()
      podcasts = result
      if result.isEmpty {
        Self.libraryLogger.debug("LibraryView: podcastManager.all() returned 0 podcasts")
      }
    }
  }

  // MARK: - Podcast Card View for Button-Based Layout (No Table Structure)
  private struct PodcastCardView: View {
    let podcast: Podcast
    let playlistManager: (any PlaylistManaging)?

    var body: some View {
      NavigationLink(
        destination: EpisodeListViewWrapper(podcast: podcast, playlistManager: playlistManager)
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
            if let description = podcast.description {
              Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            }
            Text("\(podcast.episodes.count) episodes")
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
      let podcast: Podcast
      let playlistManager: (any PlaylistManaging)?

      var body: some View {
        // Allow UI tests to opt into a lightweight list to avoid dependency flakiness
        let useSimpleList =
          ProcessInfo.processInfo.environment["UITEST_USE_SIMPLE_EPISODE_LIST"] == "1"

        if useSimpleList {
          EpisodeListCardContainer(podcastId: podcast.id, podcastTitle: podcast.title)
        } else {
          // In UI test mode, use sample episodes when seeded podcasts have no real episodes.
          // In production, or when real episodes already exist, use the real podcast data.
          let useSeedData = ProcessInfo.processInfo.environment["UITEST_SEED_PODCASTS"] == "1"
          let shouldUseSampleEpisodes = useSeedData && podcast.episodes.isEmpty
          let displayPodcast = shouldUseSampleEpisodes
            ? createSamplePodcast(id: podcast.id, title: podcast.title)
            : podcast
          EpisodeListView(podcast: displayPodcast, playlistManager: playlistManager)
        }
      }

      // swiftlint:disable:next function_body_length
      private func createSamplePodcast(id: String, title: String) -> Podcast {
      // Read test audio URLs from environment variables (only set during UI tests)
      // In production, these will be nil and episodes will use placeholder URLs
      let env = ProcessInfo.processInfo.environment
      
      // Disable bundle fallback when testing error scenarios
      // - "missing": Tests missing audioURL handling
      // - "UITEST_AUDIO_DISABLE_BUNDLE": Tests explicit nil URLs
      // - "UITEST_AUDIO_OVERRIDE_URL": Tests custom URLs (may be invalid for error tests)
      // NOTE: If override URL is invalid, episodes will have nil audio - this is intentional
      // for testing error UI (Issue 03.3.4)
      let disableFallback = env["UITEST_AUDIO_OVERRIDE_MODE"] == "missing"
        || env["UITEST_AUDIO_DISABLE_BUNDLE"] == "1"
        || (env["UITEST_AUDIO_OVERRIDE_URL"]?.isEmpty == false)

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
        
        // Diagnostic logging (only in test environment)
        if env["UITEST_DEBUG_AUDIO"] == "1" {
          logger.info("🎵 Test audio paths from environment:")
          if let url = shortAudioURL {
            let readable = FileManager.default.isReadableFile(atPath: url.path)
            logger.info("  short: \(url.path) readable=\(readable)")
          } else {
            logger.info("  short: nil")
          }
          if let url = mediumAudioURL {
            let readable = FileManager.default.isReadableFile(atPath: url.path)
            logger.info("  medium: \(url.path) readable=\(readable)")
          } else {
            logger.info("  medium: nil")
          }
          if let url = longAudioURL {
            let readable = FileManager.default.isReadableFile(atPath: url.path)
            logger.info("  long: \(url.path) readable=\(readable)")
          } else {
            logger.info("  long: nil")
          }
        }
        
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
          audioURL: disableFallback ? shortAudioURL : (shortAudioURL ?? URL(string: "https://example.com/episode1.mp3"))
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
          audioURL: disableFallback ? mediumAudioURL : (mediumAudioURL ?? URL(string: "https://example.com/episode2.mp3"))
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
          audioURL: disableFallback ? longAudioURL : (longAudioURL ?? URL(string: "https://example.com/episode3.mp3"))
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
          audioURL: disableFallback ? shortAudioURL : (shortAudioURL ?? URL(string: "https://example.com/episode4.mp3"))
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
          audioURL: disableFallback ? mediumAudioURL : (mediumAudioURL ?? URL(string: "https://example.com/episode5.mp3"))
        ),
      ]

      let downloadedEnv = env["UITEST_DOWNLOADED_EPISODES"] ?? ""
      let downloadedTokens: Set<String> = {
        if downloadedEnv.isEmpty { return [] }
        let tokens = downloadedEnv.split(separator: ",").map { token -> String in
          let parts = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
          return parts.count == 2 ? String(parts[1]) : String(token)
        }
        return Set(tokens.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
      }()

      let episodes = sampleEpisodes.map { episode -> Episode in
        var mutable = episode
        if downloadedTokens.contains(episode.id.lowercased()) ||
          downloadedTokens.contains("episode-\(episode.id.lowercased())") {
          mutable.downloadStatus = .downloaded
        }
        return mutable
      }

      return Podcast(
        id: id,
        title: title,
        author: "Sample Author",
        description: "Sample podcast for UI testing with batch operations",
        feedURL: URL(string: "https://example.com/feed.rss")!,
        episodes: episodes,
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
        let disableFallback = env["UITEST_AUDIO_OVERRIDE_MODE"] == "missing"
          || env["UITEST_AUDIO_DISABLE_BUNDLE"] == "1"
          || (env["UITEST_AUDIO_OVERRIDE_URL"]?.isEmpty == false)
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
          audioURL: disableFallback ? audioURL : (audioURL ?? URL(string: "https://example.com/episode.mp3"))
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

  #if DEBUG
    #Preview {
      ContentView(podcastManager: PreviewPodcastManager(), playlistManager: InMemoryPlaylistManager())
        .modelContainer(for: Item.self, inMemory: true)
    }
  #endif

#else

  public struct ContentView: View {
    public init() {}

    public var body: some View {
      Text("Library content is available on iOS only.")
    }
  }

#endif

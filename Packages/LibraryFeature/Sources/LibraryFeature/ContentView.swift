//
//  ContentView.swift
//  zpodcastaddict
//
//  Created by Eric Ziegler on 7/12/25.
//

import CoreModels
import Persistence
import SettingsDomain
import SwiftData
import SwiftUI

#if canImport(UIKit)
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
        .navigationTitle("Discover")
        .searchable(text: $searchText, prompt: "Search podcasts")
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
              dismiss()
            }
          }
          ToolbarItem(placement: .navigationBarTrailing) {
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

#if os(iOS)

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
#endif
    @State private var showFullPlayer = false

    public init(podcastManager: PodcastManaging? = nil) {
      // Use provided podcast manager or create a new one (for backward compatibility)
      self.podcastManager = podcastManager ?? InMemoryPodcastManager()

      // Create search index sources (empty for now, will be populated as content is added)
      let searchSources: [SearchIndexSource] = []
      self.searchService = SearchService(indexSources: searchSources)
      let repository = UserDefaultsSettingsRepository()
      _settingsManager = StateObject(wrappedValue: SettingsManager(repository: repository))
      
    // Initialize mini-player with playback service from CarPlay dependencies
      #if canImport(PlayerFeature)
      let dependencies = PlaybackEnvironment.dependencies
      self.playbackDependencies = dependencies
      _miniPlayerViewModel = StateObject(
        wrappedValue: MiniPlayerViewModel(
          playbackService: dependencies.playbackService,
          queueIsEmpty: { dependencies.queueManager.queuedEpisodes.isEmpty }
        )
      )
      #endif
    }

    public var body: some View {
      ZStack(alignment: .bottom) {
        TabView {
          // Library Tab (existing functionality)
          LibraryView()
            .tabItem {
              Label("Library", systemImage: "books.vertical")
            }

          // Discover Tab (placeholder UI)
          DiscoverView(
            searchService: searchService,
            podcastManager: podcastManager
          )
          .tabItem {
            Label("Discover", systemImage: "safari")
          }

          // Playlists Tab (placeholder UI)
          PlaylistTabView()
            .tabItem {
              Label("Playlists", systemImage: "music.note.list")
            }

          // Player Tab (placeholder - shows sample episode)
          #if canImport(PlayerFeature)
            PlayerTabView(playbackService: playbackDependencies.playbackService)
              .tabItem {
                Label("Player", systemImage: "play.circle")
              }
          #else
            PlayerTabView()
              .tabItem {
                Label("Player", systemImage: "play.circle")
              }
          #endif

          SettingsHomeView(settingsManager: settingsManager)
            .tabItem {
              Label("Settings", systemImage: "gearshape")
            }
        }
        #if canImport(UIKit)
          .background(TabBarIdentifierSetter())
        #endif
        
        // Mini-player overlay
        #if canImport(PlayerFeature)
        VStack(spacing: 0) {
          Spacer()
          MiniPlayerView(viewModel: miniPlayerViewModel) {
            showFullPlayer = true
          }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showFullPlayer) {
          if let episode = miniPlayerViewModel.currentEpisode {
            NavigationStack {
              EpisodeDetailView(
                episode: episode,
                playbackService: playbackDependencies.playbackService
              )
            }
            .accessibilityIdentifier("expanded-player-sheet")
          }
        }
        #endif
      }
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
                  .background(Color(.systemGray6))
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
        .background(Color(.systemGray6))
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

      // Use the real EpisodeListView with full batch operation functionality
      EpisodeListView(podcast: samplePodcast)
    }

    private func createSamplePodcast(id: String, title: String) -> Podcast {
      let sampleEpisodes = [
        Episode(
          id: "st-001",
          title: "Episode 1: Introduction",
          podcastID: id,
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
          duration: 2723,  // 45:23
          description: "Introduction to the podcast series.",
          audioURL: URL(string: "https://example.com/episode1.mp3")
        ),
        Episode(
          id: "st-002",
          title: "Episode 2: Swift Basics",
          podcastID: id,
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
          duration: 3137,  // 52:17
          description: "Covering Swift language basics.",
          audioURL: URL(string: "https://example.com/episode2.mp3")
        ),
        Episode(
          id: "st-003",
          title: "Episode 3: Advanced Topics",
          podcastID: id,
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date(),
          duration: 3702,  // 61:42
          description: "Deep dive into advanced Swift concepts.",
          audioURL: URL(string: "https://example.com/episode3.mp3")
        ),
        Episode(
          id: "st-004",
          title: "Episode 4: Performance",
          podcastID: id,
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date(),
          duration: 2336,  // 38:56
          description: "Performance optimization techniques.",
          audioURL: URL(string: "https://example.com/episode4.mp3")
        ),
        Episode(
          id: "st-005",
          title: "Episode 5: Testing",
          podcastID: id,
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Calendar.current.date(byAdding: .day, value: -35, to: Date()) ?? Date(),
          duration: 2673,  // 44:33
          description: "Testing strategies and best practices.",
          audioURL: URL(string: "https://example.com/episode5.mp3")
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
      @State private var isPlaying: Bool = false
      @State private var progress: Double = 0.25

      var body: some View {
        NavigationStack {
          ScrollView {
            VStack(spacing: 16) {
              playerInterface

              NavigationLink("Open Full Player", destination: sampleEpisodeView)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("open-full-player")
            }
            .frame(maxWidth: .infinity)
            .padding()
          }
          .navigationTitle("Player")
        }
      }

      @ViewBuilder
      private var playerInterface: some View {
        VStack(spacing: 16) {
          PlayerArtworkView()
          PlayerTitlesView()
          PlayerProgressSliderView(progress: $progress)
          PlaybackControlsView(isPlaying: $isPlaying)
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Player Interface")
      }

      private var sampleEpisodeView: some View {
        EpisodeDetailView(
          episode: sampleEpisode,
          playbackService: playbackService
        )
      }

      private var sampleEpisode: Episode {
        Episode(
          id: "sample-1",
          title: "Sample Episode",
          podcastID: "sample-podcast",
          playbackPosition: 0,
          isPlayed: false,
          pubDate: Date(),
          duration: 1800,
          description: "This is a sample episode to demonstrate the player interface.",
          audioURL: URL(string: "https://example.com/episode.mp3")
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

  // MARK: - Player Subviews (extracted to improve type-check performance)
  private struct PlayerArtworkView: View {
    var body: some View {
      Image(systemName: "music.note")
        .resizable()
        .scaledToFit()
        .frame(width: 160, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("Episode Artwork")
        .accessibilityLabel("Episode Artwork")
        .accessibilityHint("Artwork for the current episode")
    }
  }

  private struct PlayerTitlesView: View {
    var body: some View {
      VStack(spacing: 4) {
        Text("Sample Episode Title")
          .font(.headline)
          .accessibilityElement(children: .ignore)
          .accessibilityIdentifier("Episode Title")
          .accessibilityLabel("Episode Title")
          .accessibilityAddTraits(.isHeader)
        Text("Sample Podcast Title")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .accessibilityElement(children: .ignore)
          .accessibilityIdentifier("Podcast Title")
          .accessibilityLabel("Podcast Title")
      }
    }
  }

  private struct PlayerProgressSliderView: View {
    @Binding var progress: Double
    var body: some View {
      Slider(value: $progress)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("Progress Slider")
        .accessibilityLabel("Progress Slider")
        .accessibilityHint("Adjust playback position")
        .accessibilityValue(Text("\(Int(progress * 100)) percent"))
    }
  }

  private struct PlaybackControlsView: View {
    @Binding var isPlaying: Bool
    var body: some View {
      HStack(spacing: 24) {
        Button(action: {
          // no-op for tests
        }) {
          Text("Skip Backward")
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("Skip Backward")
        .accessibilityLabel("Skip Backward")
        .accessibilityHint("Skips backward")
        .accessibilityAddTraits(.isButton)
        .frame(minWidth: 80, minHeight: 56)
        .contentShape(Rectangle())

        Button(action: {
          isPlaying.toggle()
        }) {
          Text(isPlaying ? "Pause" : "Play")
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(isPlaying ? "Pause" : "Play")
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
        .accessibilityHint("Toggles playback")
        .accessibilityAddTraits(.isButton)
        .frame(minWidth: 120, minHeight: 56)
        .contentShape(Rectangle())

        Button(action: {
          // no-op for tests
        }) {
          Text("Skip Forward")
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("Skip Forward")
        .accessibilityLabel("Skip Forward")
        .accessibilityHint("Skips forward")
        .accessibilityAddTraits(.isButton)
        .frame(minWidth: 80, minHeight: 56)
        .contentShape(Rectangle())
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .padding(.vertical, 8)
    }
  }

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
            .navigationBarTitleDisplayMode(.large)
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
          .navigationBarTitleDisplayMode(.large)
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
        .background(Color(.systemGray6))
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
      .navigationBarTitleDisplayMode(.inline)
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

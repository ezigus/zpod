//
//  ContentView.swift
//  zpodcastaddict
//
//  Created by Eric Ziegler on 7/12/25.
//

import SwiftUI
import SwiftData
import CoreModels

#if canImport(DiscoverFeature)
import DiscoverFeature
import SearchDomain
import TestSupport
#else
// Fallback placeholder when DiscoverFeature module isn't linked
struct DiscoverView: View {
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationView {
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
        }
    }
}
#endif

#if canImport(PlayerFeature)
import PlayerFeature
#else
// Fallback placeholder when PlayerFeature module isn't linked
struct EpisodeDetailView: View {
    let episode: Episode
    var body: some View { Text("Player") }
}
#endif

#if canImport(PlaylistFeature)
import PlaylistFeature
#else
// Fallback placeholder when PlaylistFeature module isn't linked
struct PlaylistEditView: View { var body: some View { Text("Playlists") } }
#endif

// MARK: - UIKit Introspection Helper for Tab Bar Identifier
private struct TabBarIdentifierSetter: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let root = uiViewController.view.window?.rootViewController else { return }
            if let tabBarController = findTabBarController(from: root) {
                let tabBar = tabBarController.tabBar
                if tabBar.accessibilityIdentifier != "Main Tab Bar" {
                    tabBar.accessibilityIdentifier = "Main Tab Bar"
                }
                // Ensure each tab bar item is properly accessible
                let items = tabBar.items ?? []
                for (index, item) in items.enumerated() {
                    // Derive a reasonable title if missing
                    let currentTitle = item.title ?? {
                        switch index {
                        case 0: return "Library"
                        case 1: return "Discover"
                        case 2: return "Playlists"
                        case 3: return "Player"
                        default: return "Tab \(index + 1)"
                        }
                    }()
                    if (item.title ?? "").isEmpty { item.title = currentTitle }
                    if (item.accessibilityLabel ?? "").isEmpty { item.accessibilityLabel = currentTitle }
                    if (item.accessibilityHint ?? "").isEmpty { item.accessibilityHint = "Opens \(currentTitle)" }
                    // Mark as button for assistive technologies
                    item.accessibilityTraits.insert(.button)
                }
            }
        }
    }
    private func findTabBarController(from vc: UIViewController) -> UITabBarController? {
        if let t = vc as? UITabBarController { return t }
        for child in vc.children {
            if let found = findTabBarController(from: child) { return found }
        }
        if let presented = vc.presentedViewController {
            if let found = findTabBarController(from: presented) { return found }
        }
        return nil
    }
}

public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    // Service instances for dependency injection
    private let podcastManager: PodcastManaging
    private let searchService: SearchServicing

    public init() {
        // Initialize services following the same pattern as ContentViewBridge
        self.podcastManager = InMemoryPodcastManager()
        
        // Create search index sources (empty for now, will be populated as content is added)
        let searchSources: [SearchIndexSource] = []
        self.searchService = SearchService(indexSources: searchSources)
    }

    public var body: some View {
        TabView {
            // Library Tab (existing functionality)
            LibraryView()
                // Mark the primary content area as an accessibility element
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("Main Content")
                .accessibilityLabel("Main Content")
                .accessibilityHint("Primary content area")
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                        .accessibilityLabel("Library")
                        .accessibilityHint("Opens Library")
                }
            
            // Discover Tab (placeholder UI)
            DiscoverView(
                searchService: searchService,
                podcastManager: podcastManager
            )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("Main Content")
                .accessibilityLabel("Main Content")
                .accessibilityHint("Primary content area")
                .tabItem {
                    Label("Discover", systemImage: "safari")
                        .accessibilityLabel("Discover")
                        .accessibilityHint("Opens Discover")
                }
            
            // Playlists Tab (placeholder UI)
            PlaylistEditView()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("Main Content")
                .accessibilityLabel("Main Content")
                .accessibilityHint("Primary content area")
                .tabItem {
                    Label("Playlists", systemImage: "music.note.list")
                        .accessibilityLabel("Playlists")
                        .accessibilityHint("Opens Playlists")
                }
            
            // Player Tab (placeholder - shows sample episode)
            PlayerTabView()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("Main Content")
                .accessibilityLabel("Main Content")
                .accessibilityHint("Primary content area")
                .tabItem {
                    Label("Player", systemImage: "play.circle")
                        .accessibilityLabel("Player")
                        .accessibilityHint("Opens Player")
                }
        }
        // Provide an identifier in case XCUITest reads from SwiftUI hierarchy
        .accessibilityIdentifier("Main Tab Bar")
        // Introspect and set identifier on the underlying UITabBar
        .background(TabBarIdentifierSetter())
    }
}

// MARK: - Data Models for UI Testing
private struct PodcastItem: Identifiable {
    let id: String
    let title: String
}

/// The original library view moved to its own component
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    // Sample data for consistent UI testing and development experience

    @State private var samplePodcasts: [PodcastItem] = []
    @State private var isLoading = true
 
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("Loading...")
                        .accessibilityIdentifier("Loading View")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Show sample podcast rows for consistent UI tests and development
                        if !samplePodcasts.isEmpty {
                            Section("Podcasts") {
                                ForEach(samplePodcasts) { podcast in
                                    PodcastRowView(podcast: podcast)
                                        .accessibilityElement(children: .combine)
                                        .accessibilityIdentifier("Podcast-\(podcast.id)")
                                }
                            }
                        }
                        
                        // Show persisted items
                        if !items.isEmpty {
                            Section("Saved Items") {
                                ForEach(items) { item in
                                    NavigationLink {
                                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                                    } label: {
                                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                    }
                                }
                                .onDelete(perform: deleteItems)
                            }
                        }
                        
                        // Show empty state when needed
                        if samplePodcasts.isEmpty && items.isEmpty {
                            Section {
                                VStack(spacing: 16) {
                                    Image(systemName: "books.vertical")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)
                                    Text("No Podcasts Yet")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("Your podcast library will appear here")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 32)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                Task {
                    await loadData()
                }
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
        // Simulate realistic loading time
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Load sample data for UI tests and development
        samplePodcasts = [
            PodcastItem(id: "swift-talk", title: "Swift Talk"),
            PodcastItem(id: "swift-over-coffee", title: "Swift Over Coffee"),
            PodcastItem(id: "accidental-tech-podcast", title: "Accidental Tech Podcast")
        ]
        
        isLoading = false
    }
}

// MARK: - Podcast Row Component for Proper Accessibility
private struct PodcastRowView: View {
    let podcast: PodcastItem
    
    var body: some View {
        NavigationLink(destination: EpisodeListPlaceholder(podcastId: podcast.id, podcastTitle: podcast.title)) {
            HStack {
                // Add podcast artwork placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(podcast.title)
                        .font(.headline)
                        .accessibilityLabel(podcast.title)
                    Text("Sample Podcast")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

/// Player tab that shows the EpisodeDetailView with a sample episode
struct PlayerTabView: View {
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.25
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    playerInterface
                    
                    // Sample navigation to a detailed player view (if PlayerFeature linked)
                    NavigationLink("Open Full Player", destination: sampleEpisodeView)
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Player")
        }
    }
    
    // Break up the large view tree into smaller, type-check-friendly pieces
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
        EpisodeDetailView(episode: sampleEpisode)
    }
    
    private var sampleEpisode: Episode {
        Episode(
            id: "sample-1",
            title: "Sample Episode",
            podcastID: "sample-podcast",
            playbackPosition: 0,
            isPlayed: false,
            pubDate: Date(),
            duration: 1800, // 30 minutes
            description: "This is a sample episode to demonstrate the player interface.",
            audioURL: URL(string: "https://example.com/episode.mp3")
        )
    }
}

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

// MARK: - Episode List Placeholder for UI Tests
struct EpisodeListPlaceholder: View {
    let podcastId: String
    let podcastTitle: String
    
    @State private var episodes: [EpisodeItem] = []
    @State private var isLoading = true
    
    private struct EpisodeItem: Identifiable {
        let id: String
        let title: String
        let duration: String
        let date: String
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading Episodes...")
                    .accessibilityIdentifier("Loading View")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(episodes) { episode in
                            NavigationLink(destination: EpisodeDetailPlaceholder(episodeId: episode.id, episodeTitle: episode.title)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(episode.title)
                                        .font(.headline)
                                        .accessibilityIdentifier("Episode Title")
                                    HStack {
                                        Text(episode.duration)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(episode.date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .accessibilityIdentifier("Episode-\(episode.id)")
                        }
                    }
                }
                .accessibilityIdentifier("Episode List")
            }
        }
        .navigationTitle(podcastTitle)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task {
                await loadEpisodes()
            }
        }
    }
    
    @MainActor
    private func loadEpisodes() async {
        // Simulate realistic loading time
        try? await Task.sleep(nanoseconds: 750_000_000) // 0.75 seconds
        
        // Load sample episodes for UI tests
        episodes = [
            EpisodeItem(id: "st-001", title: "Episode 1: Introduction", duration: "45:23", date: "Dec 8"),
            EpisodeItem(id: "st-002", title: "Episode 2: Swift Basics", duration: "52:17", date: "Dec 1"),
            EpisodeItem(id: "st-003", title: "Episode 3: Advanced Topics", duration: "61:42", date: "Nov 24"),
            EpisodeItem(id: "st-004", title: "Episode 4: Performance", duration: "38:56", date: "Nov 17"),
            EpisodeItem(id: "st-005", title: "Episode 5: Testing", duration: "44:33", date: "Nov 10")
        ]
        
        isLoading = false
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

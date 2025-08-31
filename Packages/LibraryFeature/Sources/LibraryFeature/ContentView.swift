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
#else
// Fallback placeholder when DiscoverFeature module isn't linked
struct DiscoverView: View { var body: some View { Text("Discover") } }
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
            if let tabBar = findTabBarController(from: root)?.tabBar {
                if tabBar.accessibilityIdentifier != "Main Tab Bar" {
                    tabBar.accessibilityIdentifier = "Main Tab Bar"
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

    public init() {}

    public var body: some View {
        TabView {
            // Library Tab (existing functionality)
            LibraryView()
                .accessibilityIdentifier("Main Content")
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            
            // Discover Tab (placeholder UI)
            DiscoverView()
                .accessibilityIdentifier("Main Content")
                .tabItem {
                    Label("Discover", systemImage: "safari")
                }
            
            // Playlists Tab (placeholder UI)
            PlaylistEditView()
                .accessibilityIdentifier("Main Content")
                .tabItem {
                    Label("Playlists", systemImage: "music.note.list")
                }
            
            // Player Tab (placeholder - shows sample episode)
            PlayerTabView()
                .accessibilityIdentifier("Main Content")
                .tabItem {
                    Label("Player", systemImage: "play.circle")
                }
        }
        // Provide an identifier in case XCUITest reads from SwiftUI hierarchy
        .accessibilityIdentifier("Main Tab Bar")
        // Introspect and set identifier on the underlying UITabBar
        .background(TabBarIdentifierSetter())
    }
}

/// The original library view moved to its own component
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Library")
        } detail: {
            Text("Select an item")
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
}

/// Player tab that shows the EpisodeDetailView with a sample episode
struct PlayerTabView: View {
    @State private var isPlaying: Bool = false
    @State private var progress: Double = 0.25
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Player Interface container
                    Group {
                        // Episode artwork
                        Image(systemName: "music.note")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityElement()
                            .accessibilityIdentifier("Episode Artwork")
                            .accessibilityLabel("Episode Artwork")
                            .accessibilityHint("Artwork for the current episode")
                        
                        // Titles
                        Text("Sample Episode Title")
                            .font(.headline)
                            .accessibilityIdentifier("Episode Title")
                            .accessibilityLabel("Episode Title")
                        Text("Sample Podcast Title")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("Podcast Title")
                            .accessibilityLabel("Podcast Title")
                        
                        // Progress slider
                        Slider(value: $progress)
                            .accessibilityIdentifier("Progress Slider")
                            .accessibilityLabel("Progress Slider")
                            .accessibilityHint("Adjust playback position")
                            .accessibilityValue(Text("\(Int(progress * 100)) percent"))
                        
                        // Playback controls
                        HStack(spacing: 24) {
                            Button("Skip Backward") {
                                // no-op for tests
                            }
                            .accessibilityLabel("Skip Backward")
                            .accessibilityHint("Skips backward")
                            
                            Button(isPlaying ? "Pause" : "Play") {
                                isPlaying.toggle()
                            }
                            .accessibilityLabel(isPlaying ? "Pause" : "Play")
                            .accessibilityHint("Toggles playback")
                            
                            Button("Skip Forward") {
                                // no-op for tests
                            }
                            .accessibilityLabel("Skip Forward")
                            .accessibilityHint("Skips forward")
                        }
                        .padding(.vertical, 8)
                    }
                    .padding()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("Player Interface")
                    
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
    
    private var sampleEpisodeView: some View {
        EpisodeDetailView(episode: sampleEpisode)
    }
    
    private var sampleEpisode: Episode {
        Episode(
            id: "sample-1",
            title: "Sample Episode",
            pubDate: Date(),
            duration: 1800, // 30 minutes
            description: "This is a sample episode to demonstrate the player interface.",
            audioURL: URL(string: "https://example.com/episode.mp3")!
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

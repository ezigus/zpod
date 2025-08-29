//
//  ContentView.swift
//  zpodcastaddict
//
//  Created by Eric Ziegler on 7/12/25.
//

import SwiftUI
import SwiftData
import CoreModels
import DiscoverFeature
import PlayerFeature
import PlaylistFeature

public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    public init() {}

    public var body: some View {
        TabView {
            // Library Tab (existing functionality)
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            
            // Discover Tab (placeholder UI)
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "safari")
                }
            
            // Playlists Tab (placeholder UI)
            PlaylistEditView()
                .tabItem {
                    Label("Playlists", systemImage: "music.note.list")
                }
            
            // Player Tab (placeholder - shows sample episode)
            PlayerTabView()
                .tabItem {
                    Label("Player", systemImage: "play.circle")
                }
        }
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
    var body: some View {
        NavigationView {
            VStack {
                Text("Player")
                    .font(.largeTitle)
                    .padding()
                
                Text("Select an episode to view player details")
                    .foregroundColor(.secondary)
                    .padding()
                
                // Show sample player view
                NavigationLink("Sample Episode Player", destination: sampleEpisodeView)
                    .buttonStyle(.borderedProminent)
                    .padding()
                
                Spacer()
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
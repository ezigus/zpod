import SwiftUI
import os.log
#if canImport(zpodLib)
import zpodLib
#else
import CoreModels
#endif

/// Placeholder view for playlist editing (Issue 06 - UI screens out of scope)
struct PlaylistEditView: View {
    @StateObject private var playlistManager = InMemoryPlaylistManager()
    @State private var selectedPlaylist: Playlist?
    
    private let logger = OSLog(subsystem: "com.zpodcastaddict.playlists", category: "PlaylistViews")
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Playlist Management")
                    .font(.title)
                    .padding()
                
                Text("UI editing screens are out of scope for Issue 06")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Text("Placeholder functions implemented:")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Manual playlist CRUD operations")
                    Text("• Smart playlist creation and editing")
                    Text("• Episode addition/removal/reordering")
                    Text("• Playlist settings (shuffle, continuous playback)")
                    Text("• Rule-based smart playlist configuration")
                }
                .font(.body)
                .padding()
                
                Spacer()
                
                Button("Test Playlist Operations") {
                    testPlaylistOperations()
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Playlists")
        }
    }
    
    /// Test function demonstrating playlist operations (placeholder)
    private func testPlaylistOperations() {
        // Create a test manual playlist
        let testPlaylist = Playlist(
            name: "Test Manual Playlist",
            episodeIds: ["ep1", "ep2", "ep3"],
            continuousPlayback: true,
            shuffleAllowed: true
        )
        playlistManager.createPlaylist(testPlaylist)
        
        // Create a test smart playlist using current CoreModels API
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let smartCriteria = SmartPlaylistCriteria(
            maxEpisodes: 25,
            orderBy: .publicationDate,
            filterRules: [
                .dateRange(start: sevenDaysAgo, end: now),
                .isPlayed(false)
            ]
        )
        let testSmartPlaylist = SmartPlaylist(
            name: "Recent Unplayed Episodes",
            criteria: smartCriteria
        )
        playlistManager.createSmartPlaylist(testSmartPlaylist)
        
        os_log("Created test playlists - Manual: %{public}d, Smart: %{public}d", log: logger, type: .info, playlistManager.playlists.count, playlistManager.smartPlaylists.count)
    }
}

/// Placeholder view for smart playlist rule editing
struct SmartPlaylistRuleEditView: View {
    @State private var selectedRuleType: String = "isNew"
    @State private var daysThreshold: Int = 7
    @State private var podcastId: String = ""
    
    private let ruleTypes = ["isNew", "isDownloaded", "isUnplayed", "podcastId", "durationRange"]
    
    var body: some View {
        Form {
            Section("Rule Type") {
                Picker("Rule Type", selection: $selectedRuleType) {
                    ForEach(ruleTypes, id: \.self) { type in
                        Text(type.capitalized).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("Rule Parameters") {
                if selectedRuleType == "isNew" {
                    Stepper("Days: \(daysThreshold)", value: $daysThreshold, in: 1...30)
                } else if selectedRuleType == "podcastId" {
                    TextField("Podcast ID", text: $podcastId)
                }
            }
            
            Section {
                Text("Smart playlist rule editing UI is a placeholder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Edit Rule")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Placeholder view for playlist queue preview
struct PlaylistQueuePreviewView: View {
    let playlist: Playlist?
    let smartPlaylist: SmartPlaylist?
    @State private var shuffleEnabled = false
    
    init(playlist: Playlist) {
        self.playlist = playlist
        self.smartPlaylist = nil
    }
    
    init(smartPlaylist: SmartPlaylist) {
        self.playlist = nil
        self.smartPlaylist = smartPlaylist
    }
    
    var body: some View {
        VStack {
            HStack {
                Text(playlist?.name ?? smartPlaylist?.name ?? "Unknown Playlist")
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding()
            
            Toggle("Shuffle", isOn: $shuffleEnabled)
                .padding(.horizontal)
                .disabled(!(playlist?.shuffleAllowed ?? smartPlaylist?.shuffleAllowed ?? false))
            
            List {
                ForEach(0..<5, id: \.self) { index in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Episode \(index + 1)")
                                .font(.headline)
                            Text("Sample episode description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("30:00")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Text("Queue generation is implemented in PlaylistEngine")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
        .navigationTitle("Queue Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Playlist Edit") {
    PlaylistEditView()
}

#Preview("Smart Rule Edit") {
    NavigationView {
        SmartPlaylistRuleEditView()
    }
}

#Preview("Queue Preview - Manual") {
    NavigationView {
        PlaylistQueuePreviewView(playlist: Playlist(name: "Sample Playlist"))
    }
}

#Preview("Queue Preview - Smart") {
    NavigationView {
        PlaylistQueuePreviewView(smartPlaylist: SmartPlaylist(name: "Smart Playlist"))
    }
}

import CoreModels
import SwiftUI

// MARK: - PlaylistFeatureView

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct PlaylistFeatureView: View {
    @Bindable var viewModel: PlaylistViewModel

    public init(viewModel: PlaylistViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.playlists.isEmpty {
                    Section {
                        EmptyPlaylistsView()
                            .frame(maxWidth: .infinity)
                            .listRowInsets(.init(top: 24, leading: 16, bottom: 24, trailing: 16))
                    }
                } else {
                    Section {
                        ForEach(viewModel.playlists) { playlist in
                            NavigationLink(value: playlist.id) {
                                PlaylistRow(playlist: playlist)
                            }
                            .accessibilityIdentifier("Playlist.\(playlist.id).Row")
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deletePlaylist(id: playlist.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier("Playlist.\(playlist.id).Delete")
                            }
                            .contextMenu {
                                Button {
                                    viewModel.editingPlaylist = playlist
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button {
                                    viewModel.duplicatePlaylist(playlist)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    viewModel.deletePlaylist(id: playlist.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            viewModel.deletePlaylist(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.isShowingCreateSheet = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }
                    .accessibilityIdentifier("Playlist.CreateButton")
                }
            }
            .navigationDestination(for: String.self) { playlistID in
                if let playlist = viewModel.playlists.first(where: { $0.id == playlistID }) {
                    PlaylistDetailView(
                        playlist: playlist,
                        episodes: viewModel.episodes(for: playlist),
                        viewModel: viewModel
                    )
                } else {
                    MissingPlaylistView()
                }
            }
            .sheet(isPresented: $viewModel.isShowingCreateSheet) {
                PlaylistCreationView(viewModel: viewModel, existingPlaylist: nil)
            }
            .sheet(item: $viewModel.editingPlaylist) { playlist in
                PlaylistCreationView(viewModel: viewModel, existingPlaylist: playlist)
            }
        }
    }
}

// MARK: - PlaylistCreationView

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct PlaylistCreationView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: PlaylistViewModel
    let existingPlaylist: Playlist?

    @State private var name: String
    @State private var description: String

    public init(viewModel: PlaylistViewModel, existingPlaylist: Playlist?) {
        self.viewModel = viewModel
        self.existingPlaylist = existingPlaylist
        _name = State(initialValue: existingPlaylist?.name ?? "")
        _description = State(initialValue: existingPlaylist?.description ?? "")
    }

    private var isEditing: Bool { existingPlaylist != nil }
    private var isNameValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Playlist Info") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("PlaylistCreation.NameField")
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...)
                        .accessibilityIdentifier("PlaylistCreation.DescriptionField")
                }
            }
            .navigationTitle(isEditing ? "Edit Playlist" : "New Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("PlaylistCreation.CancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        save()
                        dismiss()
                    }
                    .disabled(!isNameValid)
                    .accessibilityIdentifier("PlaylistCreation.SaveButton")
                }
            }
        }
    }

    private func save() {
        if let existing = existingPlaylist {
            let updated = existing
                .withName(name.trimmingCharacters(in: .whitespacesAndNewlines))
                .withDescription(description)
            viewModel.updatePlaylist(updated)
        } else {
            viewModel.createPlaylist(name: name, description: description)
        }
    }
}

// MARK: - PlaylistDetailView

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
struct PlaylistDetailView: View {
    let playlist: Playlist
    let episodes: [Episode]
    var viewModel: PlaylistViewModel

    var body: some View {
        List {
            if episodes.isEmpty {
                Section {
                    EmptyEpisodesView(playlistName: playlist.name)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(.init(top: 24, leading: 16, bottom: 24, trailing: 16))
                }
            } else {
                Section(header: Text("Episodes")) {
                    ForEach(episodes) { episode in
                        EpisodeRow(episode: episode)
                            .accessibilityIdentifier("PlaylistEpisode.\(episode.id).Row")
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.removeEpisode(episode.id, from: playlist)
                                } label: {
                                    Label("Remove", systemImage: "minus.circle")
                                }
                                .accessibilityIdentifier("PlaylistEpisode.\(episode.id).Remove")
                            }
                    }
                    .onMove { source, destination in
                        viewModel.reorderEpisodes(in: playlist, from: source, to: destination)
                    }
                    .onDelete { offsets in
                        viewModel.removeEpisodes(at: offsets, from: playlist)
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        #if os(iOS)
        .toolbar {
            EditButton()
        }
        #endif
    }
}

// MARK: - Supporting Views

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
private struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(playlist.name)
                .font(.headline)
            if !playlist.description.isEmpty {
                Text(playlist.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var summaryText: String {
        let count = playlist.episodeIds.count
        guard count > 0 else { return "No episodes yet" }
        return "\(count) episode\(count == 1 ? "" : "s") • Updated \(playlist.updatedAt.relativeDescription)"
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
private struct EmptyPlaylistsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No playlists yet")
                .font(.headline)
            Text("Tap + to create your first playlist.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
private struct EmptyEpisodesView: View {
    let playlistName: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No episodes in \(playlistName)")
                .font(.headline)
            Text("Add episodes to this playlist to see them here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
private struct EpisodeRow: View {
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(episode.title)
                .font(.headline)
            if !episode.podcastTitle.isEmpty {
                Text(episode.podcastTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if let duration = episode.duration {
                    Label(duration.formattedTime, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let pubDate = episode.pubDate {
                    Label(pubDate.relativeDescription, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if episode.isPlayed {
                    Label("Played", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
private struct MissingPlaylistView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Playlist unavailable")
                .font(.headline)
            Text("This playlist could not be found.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Formatting helpers

extension TimeInterval {
    fileprivate var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: self) ?? "--"
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
extension Date {
    fileprivate var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#if DEBUG
    @available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
    struct PlaylistFeatureView_Previews: PreviewProvider {
        static let manager: InMemoryPlaylistManager = {
            let m = InMemoryPlaylistManager()
            m.createPlaylist(Playlist(
                id: "playlist-1",
                name: "Morning Commute",
                description: "Podcasts for the daily commute",
                episodeIds: ["ep-1", "ep-2"]
            ))
            m.createPlaylist(Playlist(
                id: "playlist-2",
                name: "Tech Deep Dives",
                episodeIds: ["ep-3"]
            ))
            m.createPlaylist(Playlist(
                id: "playlist-empty",
                name: "Listen Later",
                episodeIds: []
            ))
            return m
        }()

        static let sampleEpisodes: [String: [Episode]] = [
            "playlist-1": [
                Episode(
                    id: "ep-1",
                    title: "Daily News Roundup",
                    podcastID: "pod-1",
                    podcastTitle: "Morning Brief",
                    isPlayed: true,
                    pubDate: Date().addingTimeInterval(-3600),
                    duration: 1800,
                    description: "Start your day with the latest headlines.",
                    downloadStatus: .downloaded
                ),
                Episode(
                    id: "ep-2",
                    title: "Market Watch",
                    podcastID: "pod-2",
                    podcastTitle: "Finance Today",
                    pubDate: Date().addingTimeInterval(-7200),
                    duration: 1500,
                    description: "Financial insights for the morning commute.",
                    downloadStatus: .notDownloaded
                ),
            ],
            "playlist-2": [
                Episode(
                    id: "ep-3",
                    title: "SwiftUI Architecture",
                    podcastID: "pod-3",
                    podcastTitle: "Build Better Apps",
                    pubDate: Date().addingTimeInterval(-86400),
                    duration: 2700,
                    description: "Deep dive into building modular SwiftUI apps.",
                    downloadStatus: .downloading
                )
            ],
        ]

        static var previews: some View {
            PlaylistFeatureView(
                viewModel: PlaylistViewModel(
                    manager: manager,
                    episodeProvider: { playlist in sampleEpisodes[playlist.id, default: []] }
                )
            )
        }
    }
#endif

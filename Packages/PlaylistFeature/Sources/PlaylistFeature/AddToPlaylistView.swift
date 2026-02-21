import CoreModels
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// A sheet that lets users pick an existing playlist (or create a new one)
/// to add one or more episodes to. Presented from any episode context.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct AddToPlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: PlaylistViewModel
    let episodeIds: [String]
    var onComplete: (() -> Void)?

    @State private var isShowingCreateSheet = false

    public init(
        viewModel: PlaylistViewModel,
        episodeIds: [String],
        onComplete: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.episodeIds = episodeIds
        self.onComplete = onComplete
    }

    private var sortedPlaylists: [Playlist] {
        viewModel.playlists.sorted { $0.updatedAt > $1.updatedAt }
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isShowingCreateSheet = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }
                    .accessibilityIdentifier("AddToPlaylist.NewPlaylistButton")
                }

                if !sortedPlaylists.isEmpty {
                    Section("Playlists") {
                        ForEach(sortedPlaylists) { playlist in
                            Button {
                                viewModel.addEpisodes(episodeIds, to: playlist)
                                #if canImport(UIKit)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                #endif
                                onComplete?()
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(episodeCountText(for: playlist))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .accessibilityIdentifier("AddToPlaylist.\(playlist.id).Button")
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("AddToPlaylist.CancelButton")
                }
            }
            .sheet(isPresented: $isShowingCreateSheet) {
                PlaylistCreationView(viewModel: viewModel, existingPlaylist: nil)
            }
        }
    }

    private func episodeCountText(for playlist: Playlist) -> String {
        let count = playlist.episodeIds.count
        guard count > 0 else { return "No episodes" }
        return "\(count) episode\(count == 1 ? "" : "s")"
    }
}

// MARK: - Preview

#if DEBUG
    @available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
    struct AddToPlaylistView_Previews: PreviewProvider {
        static let manager: InMemoryPlaylistManager = {
            let m = InMemoryPlaylistManager()
            m.createPlaylist(Playlist(id: "pl-1", name: "Morning Commute", episodeIds: ["ep-a", "ep-b"]))
            m.createPlaylist(Playlist(id: "pl-2", name: "Tech Deep Dives", episodeIds: []))
            return m
        }()

        static var previews: some View {
            AddToPlaylistView(
                viewModel: PlaylistViewModel(manager: manager),
                episodeIds: ["ep-new"]
            )
        }
    }
#endif

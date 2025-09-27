import CoreModels
import SwiftUI

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct PlaylistFeatureView: View {
  private let playlists: [Playlist]
  private let episodesProvider: (Playlist) -> [Episode]

  public init(
    playlists: [Playlist],
    episodesProvider: @escaping (Playlist) -> [Episode]
  ) {
    self.playlists = playlists
    self.episodesProvider = episodesProvider
  }

  public var body: some View {
    NavigationStack {
      List {
        if playlists.isEmpty {
          Section {
            EmptyPlaylistsView()
              .frame(maxWidth: .infinity)
              .listRowInsets(.init(top: 24, leading: 16, bottom: 24, trailing: 16))
          }
        } else {
          Section {
            ForEach(playlists) { playlist in
              NavigationLink(value: playlist.id) {
                PlaylistRow(playlist: playlist)
              }
            }
          }
        }
      }
      .navigationTitle("Playlists")
      .navigationDestination(for: String.self) { playlistID in
        if let playlist = playlists.first(where: { $0.id == playlistID }) {
          PlaylistDetailView(
            playlist: playlist,
            episodes: episodesProvider(playlist)
          )
        } else {
          MissingPlaylistView()
        }
      }
    }
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
      Text(summaryText)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 8)
  }

  private var summaryText: String {
    let count = playlist.episodeIds.count
    guard count > 0 else { return "No episodes yet" }
    return
      "\(count) episode\(count == 1 ? "" : "s") • Updated \(playlist.updatedAt.relativeDescription)"
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
      Text("Create a playlist to start organizing your favorite episodes.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, 8)
  }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
private struct PlaylistDetailView: View {
  let playlist: Playlist
  let episodes: [Episode]

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
          }
        }
      }
    }
    .navigationTitle(playlist.name)
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
    static let playlists: [Playlist] = [
      Playlist(
        id: "playlist-1",
        name: "Morning Commute",
        episodeIds: ["ep-1", "ep-2"]
      ),
      Playlist(
        id: "playlist-2",
        name: "Tech Deep Dives",
        episodeIds: ["ep-3"]
      ),
      Playlist(
        id: "playlist-empty",
        name: "Listen Later",
        episodeIds: []
      ),
    ]

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
        playlists: playlists,
        episodesProvider: { playlist in
          sampleEpisodes[playlist.id, default: []]
        }
      )
    }
  }
#endif

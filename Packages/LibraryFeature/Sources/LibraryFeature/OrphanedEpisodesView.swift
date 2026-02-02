import CoreModels
import SwiftUI

struct OrphanedEpisodesView: View {
  @StateObject private var viewModel: OrphanedEpisodesViewModel

  init(viewModel: OrphanedEpisodesViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    List {
      if viewModel.episodes.isEmpty && !viewModel.isLoading {
        emptyState
      } else {
        ForEach(viewModel.episodes, id: \.id) { episode in
          row(for: episode)
            .swipeActions {
              Button(role: .destructive) {
                Task { await viewModel.delete(episode) }
              } label: {
                Label("Delete", systemImage: "trash")
              }
              .accessibilityIdentifier("Orphaned.Row.\(episode.id).Delete")
            }
            .accessibilityIdentifier("Orphaned.Row.\(episode.id)")
        }
      }
    }
    .overlay {
      if viewModel.isLoading {
        ProgressView("Loading…")
          .accessibilityIdentifier("Orphaned.Loading")
      }
    }
    .navigationTitle("Orphaned Episodes")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        if !viewModel.episodes.isEmpty {
          Button("Delete All", role: .destructive) {
            viewModel.showDeleteAllConfirmation = true
          }
          .accessibilityIdentifier("Orphaned.DeleteAll")
        }
      }
    }
    .confirmationDialog(
      "Delete all orphaned episodes?",
      isPresented: $viewModel.showDeleteAllConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete All", role: .destructive) {
        Task { await viewModel.deleteAll() }
      }
      Button("Cancel", role: .cancel) {}
    }
    .task {
      await viewModel.load()
    }
  }

  @ViewBuilder
  private func row(for episode: Episode) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(episode.title)
        .font(.headline)
        .lineLimit(2)
        .accessibilityIdentifier("Orphaned.Row.\(episode.id).Title")
      Text(episode.podcastTitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("Orphaned.Row.\(episode.id).Podcast")
      badges(for: episode)
    }
  }

  @ViewBuilder
  private func badges(for episode: Episode) -> some View {
    let reasons = reasonBadges(for: episode)
    if reasons.isEmpty { EmptyView() }
    else {
      HStack(spacing: 8) {
        ForEach(reasons, id: \.self) { reason in
          Text(reason)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.gray.opacity(0.15)))
            .accessibilityIdentifier("Orphaned.Row.\(episode.id).Reason.\(reason)")
        }
      }
    }
  }

  private func reasonBadges(for episode: Episode) -> [String] {
    var badges: [String] = []
    if episode.playbackPosition > 0 { badges.append("Progress") }
    if episode.isPlayed { badges.append("Played") }
    switch episode.downloadStatus {
    case .downloaded: badges.append("Downloaded")
    case .downloading: badges.append("Downloading")
    case .paused: badges.append("Download Paused")
    case .failed: badges.append("Download Failed")
    case .notDownloaded: break
    }
    if episode.isFavorited { badges.append("Favorited") }
    if episode.isBookmarked { badges.append("Bookmarked") }
    if episode.isArchived { badges.append("Archived") }
    if episode.rating != nil { badges.append("Rated") }
    return badges
  }

  @ViewBuilder
  private var emptyState: some View {
    ContentUnavailableView(
      label: { Label("No Orphaned Episodes", systemImage: "tray") },
      description: { Text("Episodes you kept with progress or downloads but removed from feeds will appear here.") }
    )
    .accessibilityIdentifier("Orphaned.EmptyState")
  }
}

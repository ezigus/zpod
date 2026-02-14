import CoreModels
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OrphanedEpisodesView: View {
  @StateObject private var viewModel: OrphanedEpisodesViewModel

  init(viewModel: OrphanedEpisodesViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    List {
      ForEach(viewModel.episodes, id: \.id) { episode in
        let quickPlayAction = {
          let _: Task<Void, Never> = Task {
            await viewModel.quickPlayEpisode(episode)
          }
        }
        row(for: episode)
          .padding(.trailing, 44) // leave space for trailing quick play control
          .overlay(alignment: .trailing) {
            if episode.audioURL != nil {
              quickPlayButton(for: episode, action: quickPlayAction, trailingPadding: 12)
            }
          }
        .contentShape(Rectangle())
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
    .accessibilityIdentifier("Orphaned.List")
    .overlay {
      if viewModel.episodes.isEmpty && !viewModel.isLoading {
        emptyState
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
        viewModel.showDeleteAllConfirmation = false
        Task { await viewModel.deleteAll() }
      }
      .accessibilityIdentifier("Orphaned.DeleteAllConfirm")
      Button("Cancel", role: .cancel) {
        viewModel.showDeleteAllConfirmation = false
      }
        .accessibilityIdentifier("Orphaned.DeleteAllCancel")
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
    if reasons.isEmpty { EmptyView() } else {
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

  @ViewBuilder
  private func quickPlayButton(
    for episode: Episode,
    action: @escaping () -> Void,
    trailingPadding: CGFloat = 0
  ) -> some View {
    #if canImport(UIKit)
      QuickPlayButtonUIKit(
        episode: episode,
        trailingPadding: trailingPadding,
        action: action
      )
    #else
      Button(action: action) {
        Image(systemName: episode.isInProgress ? "play.fill" : "play.circle")
          .foregroundStyle(.primary)
          .font(.title3)
      }
      .buttonStyle(.borderless)
      .padding(.trailing, trailingPadding)
      .accessibilityIdentifier("Orphaned.Row.\(episode.id).Play")
      .accessibilityLabel("Play \(episode.title)")
      .accessibilityHint("Resume playback from the last position")
    #endif
  }
}

// MARK: - UIKit bridge for reliable accessibility in List rows
#if canImport(UIKit)

private struct QuickPlayButtonUIKit: UIViewRepresentable {
  typealias UIViewType = UIView
  let episode: Episode
  let trailingPadding: CGFloat
  let action: () -> Void

  final class Coordinator {
    var action: () -> Void

    init(action: @escaping () -> Void) {
      self.action = action
    }

    @objc func tapped() {
      action()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(action: action)
  }

  func makeUIView(context: Context) -> UIView {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
    button.accessibilityIdentifier = "Orphaned.Row.\(episode.id).Play"
    button.accessibilityLabel = "Play \(episode.title)"
    button.accessibilityHint = "Resume playback from the last position"
    button.tintColor = .label
    button.setContentCompressionResistancePriority(.required, for: .horizontal)
    updateImage(on: button)

    let container = UIView()
    container.addSubview(button)
    NSLayoutConstraint.activate([
      button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -trailingPadding),
      button.widthAnchor.constraint(equalToConstant: 32),
      button.heightAnchor.constraint(equalToConstant: 32),
      container.heightAnchor.constraint(greaterThanOrEqualTo: button.heightAnchor)
    ])
    return container
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    guard let button = uiView.subviews.compactMap({ $0 as? UIButton }).first else { return }
    context.coordinator.action = action
    updateImage(on: button)
  }

  private func updateImage(on button: UIButton) {
    let name = episode.isInProgress ? "play.fill" : "play.circle"
    let image = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
    button.setImage(image, for: .normal)
  }
}
#endif

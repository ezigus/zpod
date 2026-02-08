//
//  EpisodeListView.swift
//  LibraryFeature
//
//  Created for Issue 02.1.1: Episode List Display and Basic Navigation
//

// swiftlint:disable file_length type_body_length

import CoreModels
import Foundation
import OSLog
import Persistence
import PlaybackEngine
import SettingsDomain
import SharedUtilities
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

private func normalizedEpisodeIDToken(_ id: String) -> String {
  let trimmed = id
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .lowercased()
  let tokenParts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
  let episodePortion = tokenParts.count == 2 ? String(tokenParts[1]) : trimmed
  if episodePortion.hasPrefix("episode-") {
    return String(episodePortion.dropFirst("episode-".count))
  }
  return episodePortion
}

/// Main episode list view that displays episodes for a given podcast with batch operation support
public struct EpisodeListView: View {
  private static let logger = Logger(subsystem: "us.zig.zpod", category: "EpisodeListView")
  let podcast: Podcast
  @StateObject private var viewModel: EpisodeListViewModel
  @State private var isRefreshing = false

  @MainActor
  public init(podcast: Podcast, filterManager: EpisodeFilterManager? = nil) {
    self.podcast = podcast
    let dependencies = EpisodeListDependencyProvider.shared
    if ProcessInfo.processInfo.environment["UITEST_DISABLE_DOWNLOAD_COORDINATOR"] != nil {
      #if DEBUG
        Self.logger.debug("EpisodeListView: using stub download coordinator for UI tests")
      #endif
      self._viewModel = StateObject(
        wrappedValue: EpisodeListViewModel(
          podcast: podcast,
          filterManager: filterManager,
          playbackService: dependencies.playbackService,
          episodeRepository: dependencies.episodeRepository,
          swipeConfigurationService: dependencies.swipeConfigurationService,
          hapticFeedbackService: dependencies.hapticsService,
          annotationRepository: dependencies.annotationRepository
        ))
    } else {
      #if DEBUG
        Self.logger.debug("EpisodeListView: using DownloadCoordinatorBridge")
      #endif
      let bridge = DownloadCoordinatorBridge.shared
      self._viewModel = StateObject(
        wrappedValue: EpisodeListViewModel(
          podcast: podcast,
          filterManager: filterManager,
          downloadProgressProvider: bridge,
          downloadManager: bridge,
          playbackService: dependencies.playbackService,
          episodeRepository: dependencies.episodeRepository,
          swipeConfigurationService: dependencies.swipeConfigurationService,
          hapticFeedbackService: dependencies.hapticsService,
          annotationRepository: dependencies.annotationRepository
        ))
    }
  }

  public var body: some View {
    VStack(spacing: 0) {
      // Batch operation progress indicators
      batchOperationProgressSection

      bannerSection

      // Multi-select toolbar (shown when in multi-select mode)
      if viewModel.isInMultiSelectMode {
        multiSelectToolbar
      }

      // Filter controls
      filterControlsSection

      // Episode list content
      episodeListContent
    }
    .navigationTitle(podcast.title)
    .platformNavigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItemGroup(placement: PlatformToolbarPlacement.primaryAction) {
        if viewModel.isInMultiSelectMode {
          Button("Done") {
            viewModel.exitMultiSelectMode()
          }
        } else {
          Button("Select") {
            viewModel.enterMultiSelectMode()
          }
          Button {
            viewModel.showingSwipeConfiguration = true
          } label: {
            Image(systemName: "slider.horizontal.3")
          }
          .accessibilityRepresentation {
            Button("Configure Swipe Actions") {}
              .accessibilityIdentifier("ConfigureSwipeActions")
          }
        }
      }
    }
    .refreshable {
      await refreshEpisodes()
    }
    .sheet(isPresented: $viewModel.showingFilterSheet) {
      EpisodeFilterSheet(
        initialFilter: viewModel.currentFilter,
        onApply: { filter in
          viewModel.setFilter(filter)
          viewModel.showingFilterSheet = false
        },
        onDismiss: {
          viewModel.showingFilterSheet = false
        }
      )
    }
    .sheet(isPresented: $viewModel.showingBatchOperationSheet) {
      BatchOperationView(
        selectedEpisodes: viewModel.selectedEpisodes,
        availableOperations: viewModel.availableBatchOperations,
        onOperationSelected: { operationType in
          let _: Task<Void, Never> = Task { @MainActor in
            await viewModel.executeBatchOperation(operationType)
          }
          viewModel.showingBatchOperationSheet = false
        },
        onCancel: {
          viewModel.showingBatchOperationSheet = false
        }
      )
    }
    .sheet(isPresented: $viewModel.showingSelectionCriteriaSheet) {
      EpisodeSelectionCriteriaView(
        onApply: { criteria in
          viewModel.selectEpisodesByCriteria(criteria)
          viewModel.showingSelectionCriteriaSheet = false
        },
        onCancel: {
          viewModel.showingSelectionCriteriaSheet = false
        }
      )
    }
    .sheet(isPresented: $viewModel.showingSwipeConfiguration) {
      SwipeActionConfigurationView(
        controller: viewModel.makeSwipeConfigurationController(),
        onSave: {
          viewModel.updateSwipeConfiguration($0)
        }
      )
    }
    .sheet(isPresented: $viewModel.showingPlaylistSelectionSheet) {
      PlaylistSelectionView(
        onPlaylistSelected: { playlistID in
          viewModel.addPendingEpisodeToPlaylist(playlistID)
        },
        onCancel: {
          viewModel.cancelPendingPlaylistSelection()
        }
      )
    }
    .sheet(
      item: $viewModel.pendingShareEpisode,
      onDismiss: {
        viewModel.clearPendingShare()
      }
    ) { episode in
      ShareSheet(items: [episodeShareText(for: episode)]) {
        viewModel.clearPendingShare()
      }
    }
    .confirmationDialog(
      "Delete Download?",
      isPresented: $viewModel.showingDeleteDownloadConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete Download", role: .destructive) {
        viewModel.confirmDeleteDownload()
      }
      .accessibilityIdentifier("DeleteDownload.Confirm")

      Button("Cancel", role: .cancel) {
        viewModel.cancelDeleteDownload()
      }
      .accessibilityIdentifier("DeleteDownload.Cancel")
    } message: {
      if let episode = viewModel.pendingDeleteDownloadEpisode {
        Text("Remove the downloaded file for \"\(episode.title)\"? It will still be available for streaming.")
      }
    }
    .accessibilityIdentifier("Episode List View")
    .task {
      await viewModel.ensureUITestBatchOverlayIfNeeded(after: 0.2)
      try? await viewModel.refreshNoteCounts()
    }
    .onChange(of: viewModel.filteredEpisodes.count) {
      Task { await viewModel.ensureUITestBatchOverlayIfNeeded() }
    }
  }

  @ViewBuilder
  private var batchOperationProgressSection: some View {
    if !viewModel.activeBatchOperations.isEmpty {
      VStack(spacing: 8) {
        ForEach(viewModel.activeBatchOperations, id: \.id) { batchOperation in
          BatchOperationProgressView(
            batchOperation: batchOperation,
            onCancel: {
              let _: Task<Void, Never> = Task { @MainActor in
                await viewModel.cancelBatchOperation(batchOperation.id)
              }
            },
            onRetry: batchOperation.failedCount > 0
              ? {
                let _: Task<Void, Never> = Task { @MainActor in
                  await viewModel.retryBatchOperation(batchOperation.id)
                }
              } : nil,
            onUndo: batchOperation.status == .completed && batchOperation.operationType.isReversible
              ? {
                let _: Task<Void, Never> = Task { @MainActor in
                  await viewModel.undoBatchOperation(batchOperation.id)
                }
              } : nil
          )
        }
      }
      .padding(.horizontal)
      .padding(.top, 8)
    }
  }

  @ViewBuilder
  private var bannerSection: some View {
    if let bannerState = viewModel.bannerState {
      EpisodeListBannerView(
        banner: bannerState,
        onDismiss: { viewModel.dismissBanner() }
      )
      .padding(.horizontal)
      .padding(.top, 8)
    }
  }

  @ViewBuilder
  private var multiSelectToolbar: some View {
    VStack(spacing: 0) {
      HStack {
        // Selection info
        Text("\(viewModel.selectedCount) selected")
          .font(.headline)
          .foregroundStyle(.primary)
          .accessibilityIdentifier("\(viewModel.selectedCount) selected")
          .accessibilityLabel("\(viewModel.selectedCount) episodes selected")

        Spacer()

        // Selection controls
        HStack(spacing: 16) {
          Button {
            viewModel.selectAllEpisodes()
          } label: {
            Text("All")
              .font(.caption)
              .foregroundStyle(.blue)
              .accessibilityIdentifier("All")
              .accessibilityLabel("Select All")
          }

          Button {
            viewModel.selectNone()
          } label: {
            Text("None")
              .font(.caption)
              .foregroundStyle(.blue)
              .accessibilityIdentifier("None")
              .accessibilityLabel("Select None")
          }

          Button {
            viewModel.invertSelection()
          } label: {
            Text("Invert")
              .font(.caption)
              .foregroundStyle(.blue)
              .accessibilityIdentifier("Invert")
              .accessibilityLabel("Invert Selection")
          }

          Button {
            viewModel.showingSelectionCriteriaSheet = true
          } label: {
            Text("Criteria")
              .font(.caption)
              .foregroundStyle(.blue)
              .accessibilityIdentifier("Criteria")
              .accessibilityLabel("Select by Criteria")
          }
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 8)

      // Action buttons
      if viewModel.hasActiveSelection {
        HStack(spacing: 12) {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              ForEach(
                [
                  BatchOperationType.markAsPlayed,
                  .markAsUnplayed,
                  .download,
                  .addToPlaylist,
                  .archive,
                  .favorite,
                  .delete,
                ], id: \.self
              ) { operationType in
                Button(action: {
                  let _: Task<Void, Never> = Task { @MainActor in
                    await viewModel.executeBatchOperation(operationType)
                  }
                }) {
                  Label(operationType.displayName, systemImage: operationType.systemIcon)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(operationColor(for: operationType))
                    .cornerRadius(8)
                }
                .accessibilityIdentifier(operationType.displayName)
                .accessibilityLabel(operationType.displayName)
              }

              Button {
                viewModel.showingBatchOperationSheet = true
              } label: {
                Text("More")
                  .font(.caption)
                  .foregroundStyle(.white)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(Color.gray)
                  .cornerRadius(8)
                  .accessibilityIdentifier("More")
                  .accessibilityLabel("More batch operations")
              }
            }
            .padding(.horizontal)
          }
        }
        .padding(.bottom, 8)
      }

      Divider()
    }
    .background(Color.platformSystemGray6)
  }

  private func operationColor(for operation: BatchOperationType) -> Color {
    switch operation {
    case .delete:
      return .red
    case .markAsPlayed, .favorite:
      return .green
    case .download:
      return .blue
    case .addToPlaylist:
      return .orange
    case .archive:
      return .purple
    default:
      return .gray
    }
  }

  @ViewBuilder
  private var filterControlsSection: some View {
    VStack(spacing: 8) {
      // Search bar
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)

        TextField(
          "Search episodes...",
          text: Binding(
            get: { viewModel.searchText },
            set: { viewModel.updateSearchText($0) }
          )
        )
        .textFieldStyle(.plain)

        if !viewModel.searchText.isEmpty {
          Button(action: { viewModel.updateSearchText("") }) {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .accessibilityLabel("Clear search")
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.platformSystemGray6)
      .cornerRadius(10)
      .padding(.horizontal)

      // Filter controls row
      HStack {
        Text(viewModel.filterSummary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("Filter Summary")

        Spacer()

        HStack(spacing: 12) {
          if viewModel.hasActiveFilters {
            Button {
              viewModel.clearFilter()
              viewModel.updateSearchText("")
            } label: {
              Text("Clear")
                .font(.caption)
                .foregroundStyle(.blue)
                .accessibilityIdentifier("Clear All Filters")
            }
          }

          EpisodeFilterButton(
            hasActiveFilters: !viewModel.currentFilter.isEmpty
          ) {
            viewModel.showingFilterSheet = true
          }
        }
      }
      .padding(.horizontal)

      // Active filters display
      if !viewModel.currentFilter.isEmpty {
        ActiveFiltersDisplay(
          filter: viewModel.currentFilter,
          onRemoveCriteria: { criteria in
            removeCriteriaFromFilter(criteria)
          },
          onClearAll: {
            viewModel.clearFilter()
          }
        )
        .padding(.horizontal)
      }
    }
    .padding(.vertical, 8)
    .background(Color.platformSystemBackground)
  }

  @ViewBuilder
  private var episodeListContent: some View {
    if viewModel.filteredEpisodes.isEmpty {
      if viewModel.hasActiveFilters {
        noResultsView
      } else {
        emptyStateView
      }
    } else {
      episodeList
    }
  }

  @ViewBuilder
  private var episodeList: some View {
    #if os(iOS)
      // iPhone layout with standard list
      List(viewModel.filteredEpisodes, id: \.id) { episode in
        if viewModel.isInMultiSelectMode {
          EpisodeRowView(
            episode: episode,
            downloadProgress: viewModel.downloadProgress(for: episode.id),
            onFavoriteToggle: { viewModel.toggleEpisodeFavorite(episode) },
            onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) },
            onPlayedStatusToggle: { viewModel.toggleEpisodePlayedStatus(episode) },
            onDownloadRetry: { viewModel.retryEpisodeDownload(episode) },
            onDownloadPause: nil,
            onDownloadResume: nil,
            onQuickPlay: nil,
            isSelected: viewModel.isEpisodeSelected(episode.id),
            isInMultiSelectMode: true,
            onSelectionToggle: { viewModel.toggleEpisodeSelection(episode) },
            noteCount: viewModel.noteCounts[episode.id],
            isDownloadDeleted: viewModel.deletedDownloadEpisodeIDs.contains(episode.id)
          )
          .accessibilityIdentifier("Episode-\(episode.id)")
        } else {
          let quickPlayAction = {
            let _: Task<Void, Never> = Task { @MainActor in
              await viewModel.quickPlayEpisode(episode)
            }
          }
          NavigationLink(destination: episodeDetailView(for: episode)) {
            EpisodeRowView(
              episode: episode,
              downloadProgress: viewModel.downloadProgress(for: episode.id),
              onFavoriteToggle: { viewModel.toggleEpisodeFavorite(episode) },
              onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) },
              onPlayedStatusToggle: { viewModel.toggleEpisodePlayedStatus(episode) },
              onDownloadRetry: { viewModel.retryEpisodeDownload(episode) },
              onDownloadPause: {
                let _: Task<Void, Never> = Task { @MainActor in
                  await viewModel.pauseEpisodeDownload(episode)
                }
              },
              onDownloadResume: {
                let _: Task<Void, Never> = Task { @MainActor in
                  await viewModel.resumeEpisodeDownload(episode)
                }
              },
              onQuickPlay: nil,
              isSelected: false,
              isInMultiSelectMode: false,
              noteCount: viewModel.noteCounts[episode.id],
              isDownloadDeleted: viewModel.deletedDownloadEpisodeIDs.contains(episode.id)
            )
          }
          .overlay(alignment: .trailing) {
            quickPlayButton(for: episode, action: quickPlayAction, trailingPadding: 12)
          }
          .swipeActions(
            edge: .trailing,
            allowsFullSwipe: viewModel.allowsFullSwipeTrailing
          ) {
            swipeButtons(for: viewModel.trailingSwipeActions, episode: episode)
          }
          .swipeActions(
            edge: .leading,
            allowsFullSwipe: viewModel.allowsFullSwipeLeading
          ) {
            swipeButtons(for: viewModel.leadingSwipeActions, episode: episode)
          }
          .accessibilityIdentifier("Episode-\(episode.id)")
          .onLongPressGesture {
            viewModel.enterMultiSelectMode()
            viewModel.toggleEpisodeSelection(episode)
          }
      }
    }
    .platformInsetGroupedListStyle()
    .accessibilityIdentifier("Episode Cards Container")
    .background(EpisodeListIdentifierSetter())
    #if DEBUG
      .overlay(alignment: .topLeading) {
        if ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1",
          !viewModel.swipeExecutionDebugSummary.isEmpty
        {
            Text(viewModel.swipeExecutionDebugSummary)
            .font(.caption2)
            .opacity(0.001)
            .accessibilityHidden(false)
            .accessibilityIdentifier("SwipeActions.Debug.LastExecution")
            .accessibilityLabel("SwipeActions.Debug.LastExecution")
            .accessibilityValue(viewModel.swipeExecutionDebugSummary)
          }
        }
      #endif
    #else
      // watchOS and CarPlay use simple list layout
      List(viewModel.filteredEpisodes, id: \.id) { episode in
        NavigationLink(destination: episodeDetailView(for: episode)) {
          EpisodeRowView(
            episode: episode,
            onFavoriteToggle: { viewModel.toggleEpisodeFavorite(episode) },
            onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) },
            onPlayedStatusToggle: { viewModel.toggleEpisodePlayedStatus(episode) },
            onDownloadRetry: { viewModel.retryEpisodeDownload(episode) },
            noteCount: viewModel.noteCounts[episode.id]
          )
        }
        .accessibilityIdentifier("Episode-\(episode.id)")
      }
      .platformInsetGroupedListStyle()
      .accessibilityIdentifier("Episode List")
    #endif
  }

  @ViewBuilder
  private func swipeButtons(for actions: [SwipeActionType], episode: Episode) -> some View {
    ForEach(actions.filter { shouldShowSwipeAction($0, for: episode) }, id: \.self) { action in
      swipeButton(for: action, episode: episode)
    }
  }

  private func shouldShowSwipeAction(_ action: SwipeActionType, for episode: Episode) -> Bool {
    switch action {
    case .deleteDownload:
      return isEffectivelyDownloaded(episode)
    default:
      return true
    }
  }

  private func isEffectivelyDownloaded(_ episode: Episode) -> Bool {
    // If already deleted this session, not downloaded
    if viewModel.deletedDownloadEpisodeIDs.contains(episode.id) {
      return false
    }
    // Model truth
    if episode.isDownloaded {
      return true
    }
    // UI test env var override
    if let envValue = ProcessInfo.processInfo.environment["UITEST_DOWNLOADED_EPISODES"],
       !envValue.isEmpty {
      let seededEpisodes = envValue
        .split(separator: ",")
        .map { rawToken in
          normalizeEpisodeIDForView(String(rawToken))
        }
      if seededEpisodes.contains(normalizeEpisodeIDForView(episode.id)) {
        return true
      }
    }
    return false
  }

  private func normalizeEpisodeIDForView(_ id: String) -> String {
    normalizedEpisodeIDToken(id)
  }

  @ViewBuilder
  private func swipeButton(for action: SwipeActionType, episode: Episode) -> some View {
    let role: ButtonRole? = action.isDestructive ? .destructive : nil
    Button(role: role) {
      viewModel.performSwipeAction(action, for: episode)
    } label: {
      Label(
        buttonTitle(for: action, episode: episode),
        systemImage: buttonSystemIcon(for: action, episode: episode))
    }
    .tint(buttonColor(for: action, episode: episode))
    .accessibilityIdentifier("SwipeAction.\(action.rawValue)")
  }

  private func buttonTitle(for action: SwipeActionType, episode: Episode) -> String {
    switch action {
    case .archive:
      return episode.isArchived ? "Unarchive" : action.displayName
    case .favorite:
      return episode.isFavorited ? "Unfavorite" : action.displayName
    default:
      return action.displayName
    }
  }

  private func buttonSystemIcon(for action: SwipeActionType, episode: Episode) -> String {
    switch action {
    case .archive:
      return episode.isArchived ? "arrow.up.bin" : action.systemIcon
    case .favorite:
      return episode.isFavorited ? "star.slash" : action.systemIcon
    default:
      return action.systemIcon
    }
  }

  private func buttonColor(for action: SwipeActionType, episode: Episode) -> Color {
    switch action {
    case .archive:
      return episode.isArchived ? .purple : Color(swipeColor: action.colorTint)
    default:
      return Color(swipeColor: action.colorTint)
    }
  }

  private func episodeShareText(for episode: Episode) -> String {
    var components: [String] = ["Listen to \"\(episode.title)\""]
    components.append("from \(podcast.title).")
    if let description = episode.description, !description.isEmpty {
      components.append(description)
    }
    return components.joined(separator: " ")
  }

  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Image(systemName: "waveform.circle")
        .resizable()
        .scaledToFit()
        .frame(width: 80, height: 80)
        .foregroundStyle(.secondary)

      Text("No Episodes")
        .font(.headline)
        .foregroundStyle(.primary)

      Text("Pull to refresh or check back later for new episodes.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("Empty Episodes State")
  }

  private var noResultsView: some View {
    VStack(spacing: 16) {
      Image(systemName: "magnifyingglass")
        .resizable()
        .scaledToFit()
        .frame(width: 60, height: 60)
        .foregroundStyle(.secondary)

      Text("No Episodes Found")
        .font(.headline)
        .foregroundStyle(.primary)

      Text("Try adjusting your filters or search terms.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button {
        viewModel.clearFilter()
        viewModel.updateSearchText("")
      } label: {
        Text("Clear Filters")
          .foregroundStyle(.blue)
          .accessibilityIdentifier("Clear Filters Button")
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("No Results State")
  }

  private func episodeDetailView(for episode: Episode) -> some View {
    // For now, a placeholder detail view
    // TODO: Implement full episode detail view in Issue #02
    VStack(spacing: 16) {
      Color.clear
        .frame(height: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("Player Interface")
        .accessibilityLabel("Player Interface")

      Text(episode.title)
        .font(.title2)
        .fontWeight(.bold)

      if let description = episode.description {
        ScrollView {
          Text(description)
            .padding()
        }
      }

      Spacer()
    }
    .navigationTitle("Episode Details")
    .platformNavigationBarTitleDisplayMode(.inline)
    .accessibilityIdentifier("Episode Detail View")
  }

  @MainActor
  private func refreshEpisodes() async {
    isRefreshing = true
    await viewModel.refreshEpisodes()
    isRefreshing = false
  }

  private func removeCriteriaFromFilter(_ criteria: EpisodeFilterCriteria) {
    let currentConditions = viewModel.currentFilter.conditions
    let newConditions = currentConditions.filter { $0.criteria != criteria }
    let newFilter = EpisodeFilter(
      conditions: newConditions,
      logic: viewModel.currentFilter.logic,
      sortBy: viewModel.currentFilter.sortBy
    )
    viewModel.setFilter(newFilter)
  }
}

#if canImport(UIKit)
  private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
      let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
      controller.completionWithItemsHandler = { _, _, _, _ in
        onDismiss()
      }
      return controller
    }

    func updateUIViewController(
      _ uiViewController: UIActivityViewController,
      context: Context
    ) {}
  }

  private struct EpisodeListIdentifierSetter: UIViewControllerRepresentable {
    private let maxAttempts = 30
    private let retryInterval: TimeInterval = 0.1

    func makeUIViewController(context: Context) -> UIViewController {
      let controller = UIViewController()
      scheduleIdentifierUpdate(from: controller, attempt: 0)
      return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
      scheduleIdentifierUpdate(from: uiViewController, attempt: 0)
    }

    private func scheduleIdentifierUpdate(from controller: UIViewController, attempt: Int) {
      let delay = attempt == 0 ? 0 : retryInterval
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        guard let tableView = self.locateTableView(startingFrom: controller) else {
          self.retryIfNeeded(from: controller, attempt: attempt)
          return
        }
        if tableView.accessibilityIdentifier != "Episode Cards Container" {
          tableView.accessibilityIdentifier = "Episode Cards Container"
          tableView.accessibilityLabel = "Episode Cards Container"
        }
      }
    }

    private func retryIfNeeded(from controller: UIViewController, attempt: Int) {
      guard attempt < maxAttempts else { return }
      scheduleIdentifierUpdate(from: controller, attempt: attempt + 1)
    }

    private func locateTableView(startingFrom controller: UIViewController) -> UITableView? {
      if let table = findTableView(in: controller.view) {
        return table
      }
      if let parent = controller.parent, let table = findTableView(in: parent.view) {
        return table
      }
      if let window = controller.view.window, let table = findTableView(in: window) {
        return table
      }
      return nil
    }

    private func findTableView(in view: UIView?) -> UITableView? {
      guard let view else { return nil }
      if let table = view as? UITableView { return table }
      for subview in view.subviews {
        if let table = findTableView(in: subview) {
          return table
        }
      }
      return nil
    }
  }
#else
  private struct ShareSheet: View {
    let items: [Any]
    let onDismiss: () -> Void

    var body: some View {
      Text("Sharing isn't available on this platform.")
        .multilineTextAlignment(.center)
        .padding()
        .onAppear(perform: onDismiss)
    }
  }
#endif

@MainActor
@ViewBuilder
private func quickPlayButton(
  for episode: Episode,
  action: @escaping () -> Void,
  trailingPadding: CGFloat = 0
) -> some View {
  Button(action: action) {
    Image(systemName: episode.isInProgress ? "play.fill" : "play.circle")
      .foregroundStyle(.primary)
      .font(.title3)
  }
  .buttonStyle(.borderless)
  .padding(.trailing, trailingPadding)
  .accessibilityLabel("Quick play")
  .accessibilityHint("Resume playback from the last position")
  .accessibilityIdentifier("Episode-\(episode.id)-QuickPlay")
}

/// Individual episode row view for the list with multi-selection support
public struct EpisodeRowView: View {
  let episode: Episode
  let downloadProgress: EpisodeDownloadProgressUpdate?
  let onFavoriteToggle: (() -> Void)?
  let onBookmarkToggle: (() -> Void)?
  let onPlayedStatusToggle: (() -> Void)?
  let onDownloadRetry: (() -> Void)?
  let onDownloadPause: (() -> Void)?
  let onDownloadResume: (() -> Void)?
  let onQuickPlay: (() -> Void)?
  let isSelected: Bool
  let isInMultiSelectMode: Bool
  let onSelectionToggle: (() -> Void)?
  let noteCount: Int?
  let isDownloadDeleted: Bool

  public init(
    episode: Episode,
    downloadProgress: EpisodeDownloadProgressUpdate? = nil,
    onFavoriteToggle: (() -> Void)? = nil,
    onBookmarkToggle: (() -> Void)? = nil,
    onPlayedStatusToggle: (() -> Void)? = nil,
    onDownloadRetry: (() -> Void)? = nil,
    onDownloadPause: (() -> Void)? = nil,
    onDownloadResume: (() -> Void)? = nil,
    onQuickPlay: (() -> Void)? = nil,
    isSelected: Bool = false,
    isInMultiSelectMode: Bool = false,
    onSelectionToggle: (() -> Void)? = nil,
    noteCount: Int? = nil,
    isDownloadDeleted: Bool = false
  ) {
    self.episode = episode
    self.downloadProgress = downloadProgress
    self.onFavoriteToggle = onFavoriteToggle
    self.onBookmarkToggle = onBookmarkToggle
    self.onPlayedStatusToggle = onPlayedStatusToggle
    self.onDownloadRetry = onDownloadRetry
    self.onDownloadPause = onDownloadPause
    self.onDownloadResume = onDownloadResume
    self.onQuickPlay = onQuickPlay
    self.isSelected = isSelected
    self.isInMultiSelectMode = isInMultiSelectMode
    self.onSelectionToggle = onSelectionToggle
    self.noteCount = noteCount
    self.isDownloadDeleted = isDownloadDeleted
  }

  public var body: some View {
    HStack(spacing: 12) {
      // Selection checkbox (only shown in multi-select mode)
      if isInMultiSelectMode {
        Button(action: {
          onSelectionToggle?()
        }) {
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isSelected ? .blue : .secondary)
            .font(.title3)
        }
        .accessibilityLabel(isSelected ? "Deselect episode" : "Select episode")
      }

      episodeArtwork

      VStack(alignment: .leading, spacing: 4) {
        episodeTitle
        episodeMetadata
        episodeDescription

        // Progress bar for downloads and playback
        progressIndicators
      }

      Spacer()

      if !isInMultiSelectMode {
        episodeStatusIndicators
      }
    }
    .padding(.vertical, 4)
    .background(isSelected && isInMultiSelectMode ? Color.blue.opacity(0.1) : Color.clear)
    .cornerRadius(8)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("Episode Row-\(episode.id)")
    .onTapGesture {
      if isInMultiSelectMode {
        onSelectionToggle?()
      }
    }
  }

  private var episodeArtwork: some View {
    AsyncImageView(
      url: episode.artworkURL,
      width: 60,
      height: 60,
      cornerRadius: 8
    )
  }

  private var episodeTitle: some View {
    Text(episode.title)
      .font(.headline)
      .lineLimit(2)
      .multilineTextAlignment(.leading)
      .accessibilityIdentifier("Episode Title")
  }

  private var episodeMetadata: some View {
    HStack(spacing: 8) {
      if let pubDate = episode.pubDate {
        Text(pubDate, style: .date)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let duration = episode.duration {
        Text(formatDuration(duration))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let noteCount, noteCount > 0 {
        noteCountBadge(noteCount)
      }
    }
    .accessibilityIdentifier("Episode Metadata")
  }

  @ViewBuilder
  private var episodeDescription: some View {
    if let description = episode.description {
      Text(description)
        .font(.caption)
        .lineLimit(2)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("Episode Description")
    }
  }

  private func noteCountBadge(_ count: Int) -> some View {
    HStack(spacing: 4) {
      Image(systemName: "note.text")
      Text("\(count)")
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(Color.accentColor.opacity(0.15))
    .foregroundStyle(Color.accentColor)
    .clipShape(Capsule())
    .accessibilityLabel("Notes: \(count)")
  }

  @ViewBuilder
  private var progressIndicators: some View {
    let showDownload = downloadProgress != nil && downloadProgress?.status != .completed
    let showPlayback = episode.isInProgress && episode.playbackProgress > 0

    if showDownload || showPlayback {
      VStack(spacing: 4) {
        if let progress = downloadProgress, progress.status != .completed {
          HStack {
            Text(downloadProgressDescription(for: progress))
              .font(.caption2)
              .foregroundStyle(.secondary)
            Spacer()
            if !isInMultiSelectMode {
              if progress.status == .paused {
                if let onDownloadResume {
                  Button("Resume", action: onDownloadResume)
                    .font(.caption2)
                    .buttonStyle(.borderless)
                }
              } else if progress.status == .downloading || progress.status == .queued {
                if let onDownloadPause {
                  Button("Pause", action: onDownloadPause)
                    .font(.caption2)
                    .buttonStyle(.borderless)
                }
              }
            }
          }
          ProgressView(value: max(0, min(progress.fractionCompleted, 1)))
            .progressViewStyle(
              LinearProgressViewStyle(tint: downloadProgressTint(for: progress.status))
            )
            .scaleEffect(y: 0.8)
            .accessibilityValue("\(Int(progress.fractionCompleted * 100)) percent")
        }

        if showPlayback {
          HStack {
            Text("Playback: \(Int(episode.playbackProgress * 100))%")
              .font(.caption2)
              .foregroundStyle(.secondary)
            Spacer()
          }
          ProgressView(value: episode.playbackProgress)
            .progressViewStyle(LinearProgressViewStyle(tint: .green))
            .scaleEffect(y: 0.8)
            .accessibilityValue("\(Int(episode.playbackProgress * 100)) percent played")
        }
      }
    }
  }

  private var episodeStatusIndicators: some View {
    VStack(spacing: 4) {
      // Top row: Play status and download with enhanced visibility
      HStack(spacing: 4) {
        // Enhanced play status indicator with single-tap functionality
        Button(action: {
          onPlayedStatusToggle?()
        }) {
          Group {
            if episode.isPlayed {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            } else if episode.isInProgress {
              Image(systemName: "play.circle.fill")
                .foregroundStyle(.blue)
            } else {
              Image(systemName: "circle")
                .foregroundStyle(.secondary)
            }
          }
          .font(.title3)
        }
        .accessibilityLabel(episode.isPlayed ? "Mark as unplayed" : "Mark as played")
        .accessibilityHint("Tap to toggle played status")

        if !isInMultiSelectMode, let onQuickPlay = onQuickPlay {
          quickPlayButton(for: episode, action: onQuickPlay)
        }

        // Enhanced download status with additional states
        downloadStatusIndicator
      }

      // Bottom row: Interactive buttons with enhanced styling
      HStack(spacing: 8) {
        if let onFavoriteToggle = onFavoriteToggle {
          Button(action: onFavoriteToggle) {
            Image(systemName: episode.isFavorited ? "heart.fill" : "heart")
              .foregroundStyle(episode.isFavorited ? .red : .secondary)
              .font(.caption)
          }
          .accessibilityLabel(episode.isFavorited ? "Remove from favorites" : "Add to favorites")
        }

        if let onBookmarkToggle = onBookmarkToggle {
          Button(action: onBookmarkToggle) {
            Image(systemName: episode.isBookmarked ? "bookmark.fill" : "bookmark")
              .foregroundStyle(episode.isBookmarked ? .blue : .secondary)
              .font(.caption)
          }
          .accessibilityLabel(episode.isBookmarked ? "Remove bookmark" : "Add bookmark")
        }

        // Archive status indicator
        if episode.isArchived {
          Image(systemName: "archivebox.fill")
            .foregroundStyle(.orange)
            .font(.caption)
            .accessibilityLabel("Archived")
        }

        // Rating indicator
        if let rating = episode.rating {
          HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
              Image(systemName: star <= rating ? "star.fill" : "star")
                .foregroundStyle(star <= rating ? .yellow : .secondary)
                .font(.caption2)
            }
          }
          .accessibilityLabel("\(rating) star rating")
        }
      }
    }
    .accessibilityIdentifier("Episode Status")
  }

  @ViewBuilder
  private var downloadStatusIndicator: some View {
    let effectiveStatus: EpisodeDownloadStatus = {
      // Skip env var override if download was explicitly deleted this session
      if isDownloadDeleted {
        return episode.downloadStatus
      }
      // UITest override: treat listed episodes as downloaded for deterministic UI
      if episode.downloadStatus == .downloaded {
        return .downloaded
      }
      if let envValue = ProcessInfo.processInfo.environment["UITEST_DOWNLOADED_EPISODES"],
         !envValue.isEmpty {
        let seededEpisodes = envValue
          .split(separator: ",")
          .map { rawToken in
            normalizeEpisodeID(String(rawToken))
          }
        if seededEpisodes.contains(normalizeEpisodeID(episode.id)) {
          return .downloaded
        }
      }
      return episode.downloadStatus
    }()

    switch effectiveStatus {
    case .downloaded:
      downloadStatusView(
        icon: "arrow.down.circle.fill",
        color: .blue,
        label: "Downloaded"
      )
    case .downloading:
      HStack(spacing: 4) {
        Image(systemName: "arrow.down.circle")
          .foregroundStyle(.blue)
        ProgressView()
          .scaleEffect(0.6)
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(downloadStatusAccessibilityIdentifier)
      .accessibilityLabel("Downloading")
    case .paused:
      HStack(spacing: 4) {
        Image(systemName: "pause.circle")
          .foregroundStyle(.yellow)
        if let progress = downloadProgress {
          Text("\(Int(progress.fractionCompleted * 100))%")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(downloadStatusAccessibilityIdentifier)
      .accessibilityLabel("Download paused")
    case .failed:
      Button(action: {
        onDownloadRetry?()
      }) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
      }
      .accessibilityIdentifier(downloadStatusAccessibilityIdentifier)
      .accessibilityLabel("Download failed, tap to retry")
    case .notDownloaded:
      EmptyView()
    }
  }

  private func normalizeEpisodeID(_ id: String) -> String {
    normalizedEpisodeIDToken(id)
  }

  private var downloadStatusAccessibilityIdentifier: String {
    "Episode-\(episode.id)-DownloadStatus"
  }

  private func downloadStatusView(
    icon: String,
    color: Color,
    label: String
  ) -> some View {
    Image(systemName: icon)
      .foregroundStyle(color)
      .accessibilityIdentifier(downloadStatusAccessibilityIdentifier)
      .accessibilityLabel(label)
  }

  private func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60

    if hours > 0 {
      return String(format: "%d:%02d:00", hours, minutes)
    } else {
      return String(format: "%d min", minutes)
    }
  }

  private func downloadProgressDescription(for progress: EpisodeDownloadProgressUpdate) -> String {
    if let message = progress.message, !message.isEmpty {
      return message
    }

    let percent = Int(progress.fractionCompleted * 100)
    switch progress.status {
    case .queued:
      return "Queued • \(percent)%"
    case .downloading:
      return "Downloading • \(percent)%"
    case .paused:
      return "Paused • \(percent)%"
    case .failed:
      return "Failed"
    case .completed:
      return "Completed"
    }
  }

  private func downloadProgressTint(for status: EpisodeDownloadProgressStatus) -> Color {
    switch status {
    case .queued:
      return .gray
    case .downloading:
      return .blue
    case .paused:
      return .yellow
    case .completed:
      return .green
    case .failed:
      return .red
    }
  }
}

// MARK: - Banner View

struct EpisodeListBannerView: View {
  let banner: EpisodeListBannerState
  let onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(banner.title)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundStyle(primaryForeground)
        Spacer()
        Button(action: onDismiss) {
          Image(systemName: "xmark")
            .font(.caption)
            .padding(6)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss banner")
      }

      Text(banner.subtitle)
        .font(.caption)
        .foregroundStyle(primaryForeground.opacity(0.8))

      HStack(spacing: 12) {
        if let retry = banner.retry {
          Button("Retry", action: retry)
            .font(.caption)
            .buttonStyle(.borderedProminent)
        }

        if let undo = banner.undo {
          Button("Undo", action: undo)
            .font(.caption)
            .buttonStyle(.bordered)
        }
        Spacer()
      }
    }
    .padding(12)
    .background(backgroundColor)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(borderColor, lineWidth: 1)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(banner.title). \(banner.subtitle)")
  }

  private var backgroundColor: Color {
    switch banner.style {
    case .success:
      return Color.green.opacity(0.1)
    case .warning:
      return Color.orange.opacity(0.1)
    case .failure:
      return Color.red.opacity(0.1)
    }
  }

  private var borderColor: Color {
    switch banner.style {
    case .success:
      return Color.green.opacity(0.4)
    case .warning:
      return Color.orange.opacity(0.4)
    case .failure:
      return Color.red.opacity(0.4)
    }
  }

  private var primaryForeground: Color {
    switch banner.style {
    case .success:
      return .green
    case .warning:
      return .orange
    case .failure:
      return .red
    }
  }
}

#Preview {
  let samplePodcast = Podcast(
    id: "sample-podcast",
    title: "Sample Podcast",
    author: "Sample Author",
    description: "A sample podcast for testing",
    artworkURL: URL(string: "https://picsum.photos/200/200?random=99"),
    feedURL: URL(string: "https://example.com/feed.xml")!,
    episodes: [
      Episode(
        id: "ep1",
        title: "Episode 1: Introduction to Swift",
        podcastID: "sample-podcast",
        pubDate: Date(),
        duration: 1800,
        description: "In this episode, we introduce the basics of Swift programming language.",
        artworkURL: URL(string: "https://picsum.photos/300/300?random=91")
      ),
      Episode(
        id: "ep2",
        title: "Episode 2: SwiftUI Fundamentals",
        podcastID: "sample-podcast",
        playbackPosition: 300,
        pubDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
        duration: 2400,
        description: "Learn about SwiftUI and building modern iOS apps.",
        artworkURL: URL(string: "https://picsum.photos/300/300?random=92")
      ),
      Episode(
        id: "ep3",
        title: "Episode 3: Advanced Swift Concepts",
        podcastID: "sample-podcast",
        isPlayed: true,
        pubDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
        duration: 3000,
        description: "Deep dive into advanced Swift programming concepts and best practices.",
        artworkURL: URL(string: "https://picsum.photos/300/300?random=93")
      ),
    ]
  )

  EpisodeListView(podcast: samplePodcast)
}

// MARK: - Dependency Provider

@MainActor
private final class EpisodeListDependencyProvider {
  static let shared = EpisodeListDependencyProvider()

  let playbackService: EpisodePlaybackService
  let episodeRepository: EpisodeRepository
  let annotationRepository: EpisodeAnnotationRepository
  let settingsManager: SettingsManager
  let swipeConfigurationService: SwipeConfigurationServicing
  let hapticsService: HapticFeedbackServicing

  private init() {
    self.playbackService = PlaybackEnvironment.playbackService
    self.episodeRepository = UserDefaultsEpisodeRepository(suiteName: "us.zig.zpod.episode-state")
    self.annotationRepository = UserDefaultsEpisodeAnnotationRepository(
      suiteName: "us.zig.zpod.episode-annotations")
    let environment = ProcessInfo.processInfo.environment
    let userDefaults: UserDefaults
    if let suiteName = environment["UITEST_USER_DEFAULTS_SUITE"], !suiteName.isEmpty,
      let suiteDefaults = UserDefaults(suiteName: suiteName)
    {
      if environment["UITEST_RESET_SWIPE_SETTINGS"] == "1" {
        suiteDefaults.removePersistentDomain(forName: suiteName)
        print("🧪 UI Test: Reset swipe settings suite '\(suiteName)'")
        suiteDefaults.synchronize()
      }
      if let seededConfigBase64 = environment["UITEST_SEEDED_SWIPE_CONFIGURATION_B64"],
        let seededData = Data(base64Encoded: seededConfigBase64)
      {
        print(
          "🧪 UI Test: Applying seeded configuration (suite). Base64 length: \(seededConfigBase64.count), Data size: \(seededData.count) bytes"
        )
        suiteDefaults.set(seededData, forKey: "global_ui_settings")
        suiteDefaults.synchronize()
        print("🧪 UI Test: Seeded configuration written to suite '\(suiteName)'")
      } else if environment["UITEST_SEEDED_SWIPE_CONFIGURATION_B64"] != nil {
        print("⚠️ UI Test: UITEST_SEEDED_SWIPE_CONFIGURATION_B64 present but base64 decode failed!")
      }
      userDefaults = suiteDefaults
    } else {
      if environment["UITEST_RESET_SWIPE_SETTINGS"] == "1" {
        if let bundleID = Bundle.main.bundleIdentifier {
          UserDefaults.standard.removePersistentDomain(forName: bundleID)
          print("🧪 UI Test: Reset swipe settings (standard UserDefaults)")
        } else {
          UserDefaults.standard.removeObject(forKey: "global_ui_settings")
          print("🧪 UI Test: Removed global_ui_settings from standard UserDefaults")
        }
      }
      if let seededConfigBase64 = environment["UITEST_SEEDED_SWIPE_CONFIGURATION_B64"],
        let seededData = Data(base64Encoded: seededConfigBase64)
      {
        print(
          "🧪 UI Test: Applying seeded configuration (standard). Base64 length: \(seededConfigBase64.count), Data size: \(seededData.count) bytes"
        )
        UserDefaults.standard.set(seededData, forKey: "global_ui_settings")
        UserDefaults.standard.synchronize()
        print("🧪 UI Test: Seeded configuration written to standard UserDefaults")
      } else if environment["UITEST_SEEDED_SWIPE_CONFIGURATION_B64"] != nil {
        print("⚠️ UI Test: UITEST_SEEDED_SWIPE_CONFIGURATION_B64 present but base64 decode failed!")
      }
      userDefaults = .standard
    }

    let settingsRepository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
    let settingsManager = SettingsManager(repository: settingsRepository)

    self.settingsManager = settingsManager
    self.swipeConfigurationService = settingsManager.swipeConfigurationService
    self.hapticsService = HapticFeedbackService.shared
  }
}

extension Color {
  fileprivate init(swipeColor: SwipeActionColor) {
    switch swipeColor {
    case .blue:
      self = .blue
    case .green:
      self = .green
    case .yellow:
      self = .yellow
    case .orange:
      self = .orange
    case .purple:
      self = .purple
    case .red:
      self = .red
    case .gray:
      self = .gray
    }
  }
}

// swiftlint:enable file_length type_body_length

//
//  EpisodeListView.swift
//  LibraryFeature
//
//  Created for Issue 02.1.1: Episode List Display and Basic Navigation
//

import SwiftUI
import CoreModels
import Persistence

#if canImport(UIKit)
import UIKit
#endif

/// Main episode list view that displays episodes for a given podcast with batch operation support
public struct EpisodeListView: View {
    let podcast: Podcast
    @StateObject private var viewModel: EpisodeListViewModel
    @State private var isRefreshing = false
    
    public init(podcast: Podcast, filterManager: EpisodeFilterManager? = nil) {
        self.podcast = podcast
        self._viewModel = StateObject(wrappedValue: EpisodeListViewModel(
            podcast: podcast, 
            filterManager: filterManager
        ))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Batch operation progress indicators
            batchOperationProgressSection
            
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
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isInMultiSelectMode {
                    Button("Done") {
                        viewModel.exitMultiSelectMode()
                    }
                } else {
                    Button("Select") {
                        viewModel.enterMultiSelectMode()
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
                    Task.detached(priority: nil) { @MainActor in
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
        .accessibilityIdentifier("Episode List View")
    }
    
    @ViewBuilder
    private var batchOperationProgressSection: some View {
        if !viewModel.activeBatchOperations.isEmpty {
            VStack(spacing: 8) {
                ForEach(viewModel.activeBatchOperations, id: \.id) { batchOperation in
                    BatchOperationProgressView(
                        batchOperation: batchOperation,
                        onCancel: {
                            Task.detached(priority: nil) { @MainActor in
                                await viewModel.cancelBatchOperation(batchOperation.id)
                            }
                        },
                        onRetry: batchOperation.failedCount > 0 ? {
                            Task.detached(priority: nil) { @MainActor in
                                await viewModel.retryBatchOperation(batchOperation.id)
                            }
                        } : nil,
                        onUndo: batchOperation.status == .completed && batchOperation.operationType.isReversible ? {
                            Task.detached(priority: nil) { @MainActor in
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
                    Button("All") {
                        viewModel.selectAllEpisodes()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .accessibilityIdentifier("All")
                    .accessibilityLabel("Select All")
                    
                    Button("None") {
                        viewModel.selectNone()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .accessibilityIdentifier("None")
                    .accessibilityLabel("Select None")
                    
                    Button("Invert") {
                        viewModel.invertSelection()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .accessibilityIdentifier("Invert")
                    .accessibilityLabel("Invert Selection")
                    
                    Button("Criteria") {
                        viewModel.showingSelectionCriteriaSheet = true
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .accessibilityIdentifier("Criteria")
                    .accessibilityLabel("Select by Criteria")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Action buttons
            if viewModel.hasActiveSelection {
                HStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach([
                                BatchOperationType.markAsPlayed,
                                .markAsUnplayed,
                                .download,
                                .addToPlaylist,
                                .favorite,
                                .delete
                            ], id: \.self) { operationType in
                                Button(action: {
                                    Task.detached(priority: nil) { @MainActor in
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
                            
                            Button("More") {
                                viewModel.showingBatchOperationSheet = true
                            }
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray)
                            .cornerRadius(8)
                            .accessibilityIdentifier("More")
                            .accessibilityLabel("More batch operations")
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 8)
            }
            
            Divider()
        }
        .background(Color(.systemGray6))
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
                
                TextField("Search episodes...", text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.updateSearchText($0) }
                ))
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
            .background(Color(.systemGray6))
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
                        Button("Clear") {
                            viewModel.clearFilter()
                            viewModel.updateSearchText("")
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .accessibilityIdentifier("Clear All Filters")
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
        .background(Color(.systemBackground))
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
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad layout with responsive columns
            LazyVGrid(columns: adaptiveColumns, spacing: 16) {
                ForEach(viewModel.filteredEpisodes, id: \.id) { episode in
                    if viewModel.isInMultiSelectMode {
                        EpisodeCardView(
                            episode: episode,
                            onFavoriteToggle: { viewModel.toggleEpisodeFavorite(episode) },
                            onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) },
                            onPlayedStatusToggle: { viewModel.toggleEpisodePlayedStatus(episode) },
                            onDownloadRetry: { viewModel.retryEpisodeDownload(episode) },
                            isSelected: viewModel.isEpisodeSelected(episode.id),
                            isInMultiSelectMode: true,
                            onSelectionToggle: { viewModel.toggleEpisodeSelection(episode) }
                        )
                        .accessibilityIdentifier("Episode-\(episode.id)")
                    } else {
                        NavigationLink(destination: episodeDetailView(for: episode)) {
                            EpisodeCardView(
                                episode: episode,
                                onFavoriteToggle: { viewModel.toggleEpisodeFavorite(episode) },
                                onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) },
                                onPlayedStatusToggle: { viewModel.toggleEpisodePlayedStatus(episode) },
                                onDownloadRetry: { viewModel.retryEpisodeDownload(episode) },
                                isSelected: false,
                                isInMultiSelectMode: false
                            )
                        }
                        .accessibilityIdentifier("Episode-\(episode.id)")
                        .onLongPressGesture {
                            viewModel.enterMultiSelectMode()
                            viewModel.toggleEpisodeSelection(episode)
                        }
                    }
                }
            }
            .padding()
            .accessibilityIdentifier("Episode Grid")
        } else {
            // iPhone layout with standard list
            List(viewModel.filteredEpisodes, id: \.id) { episode in
                if viewModel.isInMultiSelectMode {
                    EpisodeRowView(
                        episode: episode,
                        onFavoriteToggle: { viewModel.toggleEpisodeFavorite(episode) },
                        onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) },
                        onPlayedStatusToggle: { viewModel.toggleEpisodePlayedStatus(episode) },
                        onDownloadRetry: { viewModel.retryEpisodeDownload(episode) },
                        isSelected: viewModel.isEpisodeSelected(episode.id),
                        isInMultiSelectMode: true,
                        onSelectionToggle: { viewModel.toggleEpisodeSelection(episode) }
                    )
                    .accessibilityIdentifier("Episode-\(episode.id)")
                } else {
                    NavigationLink(destination: episodeDetailView(for: episode)) {
                        EpisodeRowView(
                            episode: episode,
                            onFavoriteToggle: { viewModel.toggleEpisodeFavorite(episode) },
                            onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) },
                            onPlayedStatusToggle: { viewModel.toggleEpisodePlayedStatus(episode) },
                            onDownloadRetry: { viewModel.retryEpisodeDownload(episode) },
                            isSelected: false,
                            isInMultiSelectMode: false
                        )
                    }
                    .accessibilityIdentifier("Episode-\(episode.id)")
                    .onLongPressGesture {
                        viewModel.enterMultiSelectMode()
                        viewModel.toggleEpisodeSelection(episode)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("Episode List")
        }
        #else
        // watchOS and CarPlay use simple list layout
        List(viewModel.filteredEpisodes, id: \.id) { episode in
            NavigationLink(destination: episodeDetailView(for: episode)) {
                EpisodeRowView(
                    episode: episode,
                    onFavoriteToggle: { viewModel.toggleEpisodeFavorite(episode) },
                    onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) },
                    onPlayedStatusToggle: { viewModel.toggleEpisodePlayedStatus(episode) },
                    onDownloadRetry: { viewModel.retryEpisodeDownload(episode) }
                )
            }
            .accessibilityIdentifier("Episode-\(episode.id)")
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("Episode List")
        #endif
    }
    
    // Adaptive columns for iPad grid layout
    private var adaptiveColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 300), spacing: 16)
        ]
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
            
            Button("Clear Filters") {
                viewModel.clearFilter()
                viewModel.updateSearchText("")
            }
            .foregroundStyle(.blue)
            .accessibilityIdentifier("Clear Filters Button")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("No Results State")
    }
    
    private func episodeDetailView(for episode: Episode) -> some View {
        // For now, a placeholder detail view
        // TODO: Implement full episode detail view in Issue #02
        VStack(spacing: 16) {
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
        .navigationBarTitleDisplayMode(.inline)
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

/// Individual episode row view for the list with multi-selection support
public struct EpisodeRowView: View {
    let episode: Episode
    let onFavoriteToggle: (() -> Void)?
    let onBookmarkToggle: (() -> Void)?
    let onPlayedStatusToggle: (() -> Void)?
    let onDownloadRetry: (() -> Void)?
    let onDownloadPause: (() -> Void)?
    let onQuickPlay: (() -> Void)?
    let isSelected: Bool
    let isInMultiSelectMode: Bool
    let onSelectionToggle: (() -> Void)?
    
    public init(
        episode: Episode,
        onFavoriteToggle: (() -> Void)? = nil,
        onBookmarkToggle: (() -> Void)? = nil,
        onPlayedStatusToggle: (() -> Void)? = nil,
        onDownloadRetry: (() -> Void)? = nil,
        onDownloadPause: (() -> Void)? = nil,
        onQuickPlay: (() -> Void)? = nil,
        isSelected: Bool = false,
        isInMultiSelectMode: Bool = false,
        onSelectionToggle: (() -> Void)? = nil
    ) {
        self.episode = episode
        self.onFavoriteToggle = onFavoriteToggle
        self.onBookmarkToggle = onBookmarkToggle
        self.onPlayedStatusToggle = onPlayedStatusToggle
        self.onDownloadRetry = onDownloadRetry
        self.onDownloadPause = onDownloadPause
        self.onQuickPlay = onQuickPlay
        self.isSelected = isSelected
        self.isInMultiSelectMode = isInMultiSelectMode
        self.onSelectionToggle = onSelectionToggle
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
    
    @ViewBuilder
    private var progressIndicators: some View {
        VStack(spacing: 2) {
            // Download progress
            if episode.downloadStatus == .downloading {
                HStack {
                    Text("Downloading...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ProgressView(value: 0.5) // Mock progress value
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 0.8)
            }
            
            // Playback progress
            if episode.isInProgress && episode.playbackProgress > 0 {
                HStack {
                    Text("Progress: \(Int(episode.playbackProgress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ProgressView(value: episode.playbackProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(y: 0.8)
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
        switch episode.downloadStatus {
        case .downloaded:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
                .accessibilityLabel("Downloaded")
        case .downloading:
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.blue)
                ProgressView()
                    .scaleEffect(0.6)
            }
            .accessibilityLabel("Downloading")
        case .failed:
            Button(action: {
                onDownloadRetry?()
            }) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Download failed, tap to retry")
        case .notDownloaded:
            EmptyView()
        }
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
}

/// Card-style episode view for iPad grid layout with multi-selection support
public struct EpisodeCardView: View {
    let episode: Episode
    let onFavoriteToggle: (() -> Void)?
    let onBookmarkToggle: (() -> Void)?
    let onPlayedStatusToggle: (() -> Void)?
    let onDownloadRetry: (() -> Void)?
    let isSelected: Bool
    let isInMultiSelectMode: Bool
    let onSelectionToggle: (() -> Void)?
    
    public init(
        episode: Episode,
        onFavoriteToggle: (() -> Void)? = nil,
        onBookmarkToggle: (() -> Void)? = nil,
        onPlayedStatusToggle: (() -> Void)? = nil,
        onDownloadRetry: (() -> Void)? = nil,
        isSelected: Bool = false,
        isInMultiSelectMode: Bool = false,
        onSelectionToggle: (() -> Void)? = nil
    ) {
        self.episode = episode
        self.onFavoriteToggle = onFavoriteToggle
        self.onBookmarkToggle = onBookmarkToggle
        self.onPlayedStatusToggle = onPlayedStatusToggle
        self.onDownloadRetry = onDownloadRetry
        self.isSelected = isSelected
        self.isInMultiSelectMode = isInMultiSelectMode
        self.onSelectionToggle = onSelectionToggle
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selection overlay (shown in multi-select mode)
            if isInMultiSelectMode {
                HStack {
                    Spacer()
                    Button(action: {
                        onSelectionToggle?()
                    }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .blue : .secondary)
                            .font(.title2)
                    }
                    .accessibilityLabel(isSelected ? "Deselect episode" : "Select episode")
                }
            }
            
            // Large artwork for card layout
            episodeArtwork
            
            VStack(alignment: .leading, spacing: 8) {
                episodeTitle
                episodeMetadata
                episodeDescription
                
                // Progress indicators
                progressIndicators
            }
            
            Spacer()
            
            // Bottom section with status
            HStack {
                if !isInMultiSelectMode {
                    episodeStatusIndicators
                }
                Spacer()
            }
        }
        .padding()
        .background(isSelected && isInMultiSelectMode ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected && isInMultiSelectMode ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(radius: isSelected && isInMultiSelectMode ? 4 : 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Episode Card-\(episode.id)")
        .onTapGesture {
            if isInMultiSelectMode {
                onSelectionToggle?()
            }
        }
    }
    
    private var episodeArtwork: some View {
        AsyncImageView(
            url: episode.artworkURL,
            width: 300, // Full width of card
            height: 120,
            cornerRadius: 8
        )
    }
    
    private var episodeTitle: some View {
        Text(episode.title)
            .font(.headline)
            .lineLimit(3)
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
        }
        .accessibilityIdentifier("Episode Metadata")
    }
    
    @ViewBuilder
    private var episodeDescription: some View {
        if let description = episode.description {
            Text(description)
                .font(.caption)
                .lineLimit(3)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("Episode Description")
        }
    }
    
    @ViewBuilder
    private var progressIndicators: some View {
        VStack(spacing: 2) {
            // Download progress
            if episode.downloadStatus == .downloading {
                HStack {
                    Text("Downloading...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ProgressView(value: 0.5) // Mock progress value
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 0.8)
            }
            
            // Playback progress
            if episode.isInProgress && episode.playbackProgress > 0 {
                HStack {
                    Text("Progress: \(Int(episode.playbackProgress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ProgressView(value: episode.playbackProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(y: 0.8)
            }
        }
    }
    
    private var episodeStatusIndicators: some View {
        HStack(spacing: 12) {
            // Enhanced play status with single-tap functionality
            Button(action: {
                onPlayedStatusToggle?()
            }) {
                HStack(spacing: 4) {
                    Group {
                        if episode.isPlayed {
                            Label("Played", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if episode.isInProgress {
                            Label("In Progress", systemImage: "play.circle.fill")
                                .foregroundStyle(.blue)
                        } else {
                            Label("Unplayed", systemImage: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
            }
            .accessibilityLabel(episode.isPlayed ? "Mark as unplayed" : "Mark as played")
            .accessibilityHint("Tap to toggle played status")
            
            Spacer()
            
            // Enhanced status indicators and interactive buttons
            HStack(spacing: 12) {
                // Download status with enhanced feedback
                downloadStatusIndicator
                
                if let onFavoriteToggle = onFavoriteToggle {
                    Button(action: onFavoriteToggle) {
                        Image(systemName: episode.isFavorited ? "heart.fill" : "heart")
                            .foregroundStyle(episode.isFavorited ? .red : .secondary)
                    }
                    .accessibilityLabel(episode.isFavorited ? "Remove from favorites" : "Add to favorites")
                }
                
                if let onBookmarkToggle = onBookmarkToggle {
                    Button(action: onBookmarkToggle) {
                        Image(systemName: episode.isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(episode.isBookmarked ? .blue : .secondary)
                    }
                    .accessibilityLabel(episode.isBookmarked ? "Remove bookmark" : "Add bookmark")
                }
                
                // Archive status indicator
                if episode.isArchived {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(.orange)
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
            .font(.caption)
        }
        .accessibilityIdentifier("Episode Status")
    }
    
    @ViewBuilder
    private var downloadStatusIndicator: some View {
        switch episode.downloadStatus {
        case .downloaded:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
                .accessibilityLabel("Downloaded")
        case .downloading:
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.blue)
                ProgressView()
                    .scaleEffect(0.6)
            }
            .accessibilityLabel("Downloading")
        case .failed:
            Button(action: {
                onDownloadRetry?()
            }) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            .accessibilityLabel("Download failed, tap to retry")
        case .notDownloaded:
            EmptyView()
        }
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
            )
        ]
    )
    
    EpisodeListView(podcast: samplePodcast)
}
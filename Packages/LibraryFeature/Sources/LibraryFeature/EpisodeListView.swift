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

/// Main episode list view that displays episodes for a given podcast
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
            // Filter controls
            filterControlsSection
            
            // Episode list content
            episodeListContent
        }
        .navigationTitle(podcast.title)
        .navigationBarTitleDisplayMode(.large)
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
        .accessibilityIdentifier("Episode List View")
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
                    NavigationLink(destination: episodeDetailView(for: episode)) {
                        EpisodeCardView(
                            episode: episode,
                            onFavoriteToggle: { viewModel.toggleEpisodeFavorite(episode) },
                            onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) }
                        )
                    }
                    .accessibilityIdentifier("Episode-\(episode.id)")
                }
            }
            .padding()
            .accessibilityIdentifier("Episode Grid")
        } else {
            // iPhone layout with standard list
            List(viewModel.filteredEpisodes, id: \.id) { episode in
                NavigationLink(destination: episodeDetailView(for: episode)) {
                    EpisodeRowView(
                        episode: episode,
                        onFavoriteToggle: { viewModel.toggleEpisodeFavorite(episode) },
                        onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) }
                    )
                }
                .accessibilityIdentifier("Episode-\(episode.id)")
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
                    onBookmarkToggle: { viewModel.toggleEpisodeBookmark(episode) }
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

/// Individual episode row view for the list
public struct EpisodeRowView: View {
    let episode: Episode
    let onFavoriteToggle: (() -> Void)?
    let onBookmarkToggle: (() -> Void)?
    
    public init(
        episode: Episode,
        onFavoriteToggle: (() -> Void)? = nil,
        onBookmarkToggle: (() -> Void)? = nil
    ) {
        self.episode = episode
        self.onFavoriteToggle = onFavoriteToggle
        self.onBookmarkToggle = onBookmarkToggle
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            episodeArtwork
            
            VStack(alignment: .leading, spacing: 4) {
                episodeTitle
                episodeMetadata
                episodeDescription
            }
            
            Spacer()
            
            episodeStatusIndicators
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Episode Row-\(episode.id)")
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
    
    private var episodeStatusIndicators: some View {
        VStack(spacing: 4) {
            // Top row: Play status and download
            HStack(spacing: 4) {
                if episode.isPlayed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Played")
                } else if episode.isInProgress {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.blue)
                        .accessibilityLabel("In Progress")
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Unplayed")
                }
                
                if episode.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                        .accessibilityLabel("Downloaded")
                }
            }
            
            // Bottom row: Interactive buttons
            HStack(spacing: 8) {
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
            }
            .font(.caption)
        }
        .accessibilityIdentifier("Episode Status")
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

/// Card-style episode view for iPad grid layout
public struct EpisodeCardView: View {
    let episode: Episode
    let onFavoriteToggle: (() -> Void)?
    let onBookmarkToggle: (() -> Void)?
    
    public init(
        episode: Episode,
        onFavoriteToggle: (() -> Void)? = nil,
        onBookmarkToggle: (() -> Void)? = nil
    ) {
        self.episode = episode
        self.onFavoriteToggle = onFavoriteToggle
        self.onBookmarkToggle = onBookmarkToggle
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Large artwork for card layout
            episodeArtwork
            
            VStack(alignment: .leading, spacing: 8) {
                episodeTitle
                episodeMetadata
                episodeDescription
            }
            
            Spacer()
            
            // Bottom section with status
            HStack {
                episodeStatusIndicators
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Episode Card-\(episode.id)")
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
    
    private var episodeStatusIndicators: some View {
        HStack(spacing: 12) {
            // Play status
            HStack(spacing: 4) {
                if episode.isPlayed {
                    Label("Played", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if episode.isInProgress {
                    Label("In Progress", systemImage: "play.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Label("Unplayed", systemImage: "circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Interactive buttons
            HStack(spacing: 12) {
                if episode.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                        .accessibilityLabel("Downloaded")
                }
                
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
            }
            .font(.caption)
        }
        .accessibilityIdentifier("Episode Status")
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
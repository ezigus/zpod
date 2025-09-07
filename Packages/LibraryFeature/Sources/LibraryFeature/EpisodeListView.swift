//
//  EpisodeListView.swift
//  LibraryFeature
//
//  Created for Issue 02.1.1: Episode List Display and Basic Navigation
//

import SwiftUI
import CoreModels

#if canImport(UIKit)
import UIKit
#endif

/// Main episode list view that displays episodes for a given podcast
public struct EpisodeListView: View {
    let podcast: Podcast
    @State private var episodes: [Episode]
    @State private var isRefreshing = false
    
    public init(podcast: Podcast) {
        self.podcast = podcast
        self._episodes = State(initialValue: podcast.episodes)
    }
    
    public var body: some View {
        NavigationView {
            episodeListContent
                .navigationTitle(podcast.title)
                .navigationBarTitleDisplayMode(.large)
                .refreshable {
                    await refreshEpisodes()
                }
        }
    }
    
    @ViewBuilder
    private var episodeListContent: some View {
        if episodes.isEmpty {
            emptyStateView
        } else {
            episodeList
        }
    }
    
    private var episodeList: some View {
        Group {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad layout with responsive columns
                LazyVGrid(columns: adaptiveColumns, spacing: 16) {
                    ForEach(episodes, id: \.id) { episode in
                        NavigationLink(destination: episodeDetailView(for: episode)) {
                            EpisodeCardView(episode: episode)
                        }
                        .accessibilityIdentifier("Episode-\(episode.id)")
                    }
                }
                .padding()
                .accessibilityIdentifier("Episode Grid")
            } else {
                // iPhone layout with standard list
                List(episodes, id: \.id) { episode in
                    NavigationLink(destination: episodeDetailView(for: episode)) {
                        EpisodeRowView(episode: episode)
                    }
                    .accessibilityIdentifier("Episode-\(episode.id)")
                }
                .listStyle(.insetGrouped)
                .accessibilityIdentifier("Episode List")
            }
            #else
            // Default list for other platforms
            List(episodes, id: \.id) { episode in
                NavigationLink(destination: episodeDetailView(for: episode)) {
                    EpisodeRowView(episode: episode)
                }
                .accessibilityIdentifier("Episode-\(episode.id)")
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("Episode List")
            #endif
        }
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
        // TODO: Implement actual episode refresh logic
        // For now, simulate a refresh delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        isRefreshing = false
    }
}

/// Individual episode row view for the list
public struct EpisodeRowView: View {
    let episode: Episode
    
    public init(episode: Episode) {
        self.episode = episode
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
        RoundedRectangle(cornerRadius: 8)
            .fill(.secondary.opacity(0.2))
            .frame(width: 60, height: 60)
            .overlay {
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
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
            if episode.isPlayed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Played")
            } else if episode.playbackPosition > 0 {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.blue)
                    .accessibilityLabel("In Progress")
            }
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
    
    public init(episode: Episode) {
        self.episode = episode
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
        RoundedRectangle(cornerRadius: 8)
            .fill(.secondary.opacity(0.2))
            .frame(height: 120)
            .overlay {
                Image(systemName: "waveform")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
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
        HStack(spacing: 8) {
            if episode.isPlayed {
                Label("Played", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Played")
            } else if episode.playbackPosition > 0 {
                Label("In Progress", systemImage: "play.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .accessibilityLabel("In Progress")
            }
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
        feedURL: URL(string: "https://example.com/feed.xml")!,
        episodes: [
            Episode(
                id: "ep1",
                title: "Episode 1: Introduction to Swift",
                podcastID: "sample-podcast",
                pubDate: Date(),
                duration: 1800,
                description: "In this episode, we introduce the basics of Swift programming language."
            ),
            Episode(
                id: "ep2",
                title: "Episode 2: SwiftUI Fundamentals",
                podcastID: "sample-podcast",
                playbackPosition: 300,
                pubDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                duration: 2400,
                description: "Learn about SwiftUI and building modern iOS apps."
            ),
            Episode(
                id: "ep3",
                title: "Episode 3: Advanced Swift Concepts",
                podcastID: "sample-podcast",
                isPlayed: true,
                pubDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
                duration: 3000,
                description: "Deep dive into advanced Swift programming concepts and best practices."
            )
        ]
    )
    
    EpisodeListView(podcast: samplePodcast)
}
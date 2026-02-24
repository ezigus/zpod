import CoreModels
import SwiftUI

// MARK: - SmartPlaylistAnalyticsDashboard

/// Aggregate analytics overview across all smart playlists.
///
/// Displays all playlists ranked by play count with summary stats.
/// Tapping a row opens the existing per-playlist `SmartPlaylistAnalyticsView`.
///
/// Accessed via the "Analytics" toolbar button on the Playlists tab.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct SmartPlaylistAnalyticsDashboard: View {

    var viewModel: SmartPlaylistViewModel

    @State private var sortOption: AnalyticsSortOption = .mostPlayed
    @State private var selectedPlaylist: SmartEpisodeListV2?

    public init(viewModel: SmartPlaylistViewModel) {
        self.viewModel = viewModel
    }

    private var sortedPlaylists: [(playlist: SmartEpisodeListV2, stats: SmartPlaylistStats)] {
        let pairs = viewModel.smartPlaylists.map { pl in
            (playlist: pl, stats: viewModel.stats(for: pl))
        }
        switch sortOption {
        case .mostPlayed:
            return pairs.sorted { $0.stats.totalPlays > $1.stats.totalPlays }
        case .mostRecent:
            return pairs.sorted {
                ($0.stats.mostRecentPlay ?? .distantPast) > ($1.stats.mostRecentPlay ?? .distantPast)
            }
        case .alphabetical:
            return pairs.sorted { $0.playlist.name < $1.playlist.name }
        }
    }

    private var totalPlays: Int {
        viewModel.smartPlaylists
            .map { viewModel.stats(for: $0).totalPlays }
            .reduce(0, +)
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.smartPlaylists.isEmpty {
                    AnalyticsDashboardEmptyState()
                } else {
                    List {
                        // Summary header card
                        Section {
                            AnalyticsSummaryCard(
                                totalPlaylists: viewModel.smartPlaylists.count,
                                totalPlays: totalPlays
                            )
                            .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }

                        // Per-playlist rows
                        Section("Playlists") {
                            ForEach(sortedPlaylists, id: \.playlist.id) { pair in
                                Button {
                                    selectedPlaylist = pair.playlist
                                } label: {
                                    AnalyticsPlaylistRow(
                                        playlist: pair.playlist,
                                        stats: pair.stats
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("AnalyticsDashboard.Playlist.\(pair.playlist.id)")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Playlist Analytics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(AnalyticsSortOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                    .accessibilityIdentifier("AnalyticsDashboard.SortMenu")
                }
            }
            .sheet(item: $selectedPlaylist) { playlist in
                SmartPlaylistAnalyticsView(smartPlaylist: playlist, viewModel: viewModel)
            }
        }
    }
}

// MARK: - AnalyticsSortOption

enum AnalyticsSortOption: String, CaseIterable, Identifiable {
    case mostPlayed, mostRecent, alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mostPlayed: return "Most Played"
        case .mostRecent: return "Most Recent"
        case .alphabetical: return "Alphabetical"
        }
    }
}

// MARK: - AnalyticsSummaryCard

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct AnalyticsSummaryCard: View {
    let totalPlaylists: Int
    let totalPlays: Int

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(totalPlaylists)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Playlists")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("\(totalPlays)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Total Plays")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("AnalyticsDashboard.SummaryCard")
    }
}

// MARK: - AnalyticsPlaylistRow

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct AnalyticsPlaylistRow: View {
    let playlist: SmartEpisodeListV2
    let stats: SmartPlaylistStats

    private var lastPlayedText: String {
        guard let date = stats.mostRecentPlay else { return "Never played" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: playlist.isSystemGenerated ? "wand.and.stars" : "sparkles")
                    .foregroundStyle(playlist.isSystemGenerated ? .blue : .purple)
                    .font(.subheadline)
                Text(playlist.name)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label("\(stats.totalPlays) plays", systemImage: "play.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(lastPlayedText, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AnalyticsDashboardEmptyState

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct AnalyticsDashboardEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Smart Playlists Yet")
                .font(.headline)
            Text("Create smart playlists and start listening to see analytics here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .accessibilityIdentifier("AnalyticsDashboard.EmptyState")
    }
}

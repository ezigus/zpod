import CoreModels
import SwiftUI

// MARK: - ListeningHistoryStatsView

/// Stat card grid showing total listening time, episodes started/completed,
/// completion rate, and streak information.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ListeningHistoryStatsView: View {
    let viewModel: ListeningHistoryViewModel

    var body: some View {
        let stats = viewModel.statistics
        ScrollView {
            VStack(spacing: 20) {
                // Primary stat cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    HistoryStatCard(
                        title: "Time Listened",
                        value: viewModel.formattedTotalTime,
                        systemImage: "headphones",
                        color: .blue
                    )
                    .accessibilityIdentifier("ListeningHistory.Stats.TotalTime")

                    HistoryStatCard(
                        title: "Completion Rate",
                        value: viewModel.formattedCompletionRate,
                        systemImage: "checkmark.circle.fill",
                        color: .green
                    )
                    .accessibilityIdentifier("ListeningHistory.Stats.CompletionRate")

                    HistoryStatCard(
                        title: "Episodes Started",
                        value: "\(stats.episodesStarted)",
                        systemImage: "play.circle",
                        color: .orange
                    )
                    .accessibilityIdentifier("ListeningHistory.Stats.EpisodesStarted")

                    HistoryStatCard(
                        title: "Daily Average",
                        value: viewModel.formattedDailyAverage,
                        systemImage: "calendar.badge.clock",
                        color: .purple
                    )
                    .accessibilityIdentifier("ListeningHistory.Stats.DailyAverage")
                }

                // Streak section
                if stats.currentStreak > 0 || stats.longestStreak > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Streaks")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            HistoryStatCard(
                                title: "Current Streak",
                                value: "\(stats.currentStreak)d",
                                systemImage: "flame.fill",
                                color: .red
                            )
                            .accessibilityIdentifier("ListeningHistory.Stats.CurrentStreak")

                            HistoryStatCard(
                                title: "Longest Streak",
                                value: "\(stats.longestStreak)d",
                                systemImage: "trophy.fill",
                                color: .yellow
                            )
                            .accessibilityIdentifier("ListeningHistory.Stats.LongestStreak")
                        }
                    }
                }

                // Top podcasts section
                if !stats.topPodcasts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Podcasts")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(stats.topPodcasts.prefix(5), id: \.podcastId) { podcast in
                            TopPodcastRow(
                                title: podcast.podcastTitle,
                                totalTime: podcast.totalTime
                            )
                        }
                    }
                }

                // Insights section
                if !viewModel.insights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Insights")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.insights) { insight in
                            HStack(spacing: 12) {
                                Image(systemName: insight.systemImage)
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                Text(insight.text)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal)
                            .accessibilityIdentifier("ListeningHistory.Insight.\(insight.id)")
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - HistoryStatCard

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct HistoryStatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

// MARK: - TopPodcastRow

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct TopPodcastRow: View {
    let title: String
    let totalTime: TimeInterval

    private var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalTime) ?? "--"
    }

    var body: some View {
        HStack {
            Image(systemName: "headphones")
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(formattedTime)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

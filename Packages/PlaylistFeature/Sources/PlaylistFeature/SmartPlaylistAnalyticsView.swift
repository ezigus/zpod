import CoreModels
import SwiftUI

// MARK: - SmartPlaylistAnalyticsView

/// Stats dashboard showing play event analytics for a smart playlist.
///
/// Displays total plays, unique episode count, listening duration, and
/// human-readable insights derived from the analytics event log.
/// Accessed via the toolbar button on `SmartPlaylistDetailView`.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct SmartPlaylistAnalyticsView: View {
    let smartPlaylist: SmartEpisodeListV2
    var viewModel: SmartPlaylistViewModel

    @State private var exportURL: URL?
    @State private var showingExportSheet = false
    @State private var exportError: String?

    public init(smartPlaylist: SmartEpisodeListV2, viewModel: SmartPlaylistViewModel) {
        self.smartPlaylist = smartPlaylist
        self.viewModel = viewModel
    }

    private var analyticsStats: SmartPlaylistStats {
        viewModel.stats(for: smartPlaylist)
    }

    private var analyticsInsights: [SmartPlaylistInsight] {
        viewModel.insights(for: smartPlaylist)
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Stats (Last 90 Days)") {
                    AnalyticsStatRow(
                        label: "Total Plays",
                        value: "\(analyticsStats.totalPlays)",
                        systemImage: "play.fill"
                    )
                    .accessibilityIdentifier("SmartPlaylistAnalytics.TotalPlays")

                    AnalyticsStatRow(
                        label: "Unique Episodes",
                        value: "\(analyticsStats.uniqueEpisodesPlayed)",
                        systemImage: "sparkles"
                    )
                    .accessibilityIdentifier("SmartPlaylistAnalytics.UniqueEpisodes")

                    if analyticsStats.totalPlaybackDuration > 0 {
                        AnalyticsStatRow(
                            label: "Total Listening",
                            value: analyticsStats.totalPlaybackDuration.analyticsFormattedDuration,
                            systemImage: "clock.fill"
                        )
                        .accessibilityIdentifier("SmartPlaylistAnalytics.TotalListening")
                    }

                    if let recent = analyticsStats.mostRecentPlay {
                        AnalyticsStatRow(
                            label: "Last Played",
                            value: recent.analyticsRelativeDescription,
                            systemImage: "calendar"
                        )
                        .accessibilityIdentifier("SmartPlaylistAnalytics.LastPlayed")
                    }
                }

                Section("Insights") {
                    if analyticsInsights.isEmpty {
                        Text("No insights yet. Start playing episodes from this playlist.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(analyticsInsights) { insight in
                            HStack(spacing: 12) {
                                Image(systemName: insight.systemImage)
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                Text(insight.text)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                            .accessibilityIdentifier("SmartPlaylistAnalytics.Insight.\(insight.id)")
                        }
                    }
                }

                Section("Recommendations") {
                    SmartPlaylistRecommendationsView(insights: analyticsInsights)
                }

                Section {
                    Button {
                        exportEvents()
                    } label: {
                        Label("Export Play History (JSON)", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("SmartPlaylistAnalytics.ExportButton")
                    .disabled(analyticsStats.totalPlays == 0)

                    if let error = exportError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Analytics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareLink(
                        item: url,
                        subject: Text("\(smartPlaylist.name) Play History"),
                        message: Text("Exported play events from \"\(smartPlaylist.name)\".")
                    )
                } else {
                    Text("Export file unavailable.")
                        .font(.subheadline)
                        .padding()
                }
            }
        }
    }

    private func exportEvents() {
        do {
            let data = try viewModel.exportJSON(for: smartPlaylist)
            guard let url = writeExportFile(data: data) else {
                showingExportSheet = false
                exportURL = nil
                exportError = "Export failed: unable to write file."
                return
            }
            exportURL = url
            showingExportSheet = true
            exportError = nil
        } catch {
            showingExportSheet = false
            exportURL = nil
            exportError = "Export failed: \(error.localizedDescription)"
        }
    }

    private func writeExportFile(data: Data) -> URL? {
        let safeName = smartPlaylist.name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let fileName = "\(safeName)_play_history.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return url
    }
}

// MARK: - AnalyticsStatRow

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct AnalyticsStatRow: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Formatting Helpers

private extension TimeInterval {
    var analyticsFormattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: self) ?? "--"
    }
}

private extension Date {
    var analyticsRelativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

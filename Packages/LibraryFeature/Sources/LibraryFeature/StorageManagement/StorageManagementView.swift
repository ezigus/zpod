import SwiftUI

/// Storage management view showing download storage usage and cleanup options
///
/// **Issue**: #28.1 - Phase 2: Storage Management UI
public struct StorageManagementView: View {

    @State private var viewModel = StorageManagementViewModel()
    @State private var showingDeleteAllConfirmation = false

    public init() {}

    public var body: some View {
        List {
            // Total Storage Summary Section
            Section {
                StorageSummaryRow(stats: viewModel.storageStats)
            } header: {
                Text("Total Storage Used")
            }

            // Per-Podcast Breakdown Section
            if !viewModel.storageStats.podcastBreakdown.isEmpty {
                Section {
                    ForEach(viewModel.storageStats.podcastBreakdown) { podcastInfo in
                        PodcastStorageRow(info: podcastInfo)
                    }
                } header: {
                    Text("By Podcast")
                }
            }

            // Delete All Section
            if !viewModel.storageStats.podcastBreakdown.isEmpty {
                Section {
                    Button(role: .destructive) {
                        showingDeleteAllConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete All Downloads")
                        }
                    }
                } footer: {
                    Text("This will delete all downloaded episodes and free up \(viewModel.storageStats.formattedTotal).")
                }
            }
        }
        .navigationTitle("Manage Storage")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .task {
            await viewModel.calculateStorage()
        }
        .refreshable {
            await viewModel.calculateStorage()
        }
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color.gray.opacity(0.2)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .confirmationDialog(
            "Delete All Downloads?",
            isPresented: $showingDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                Task {
                    await viewModel.deleteAllDownloads()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all \(viewModel.storageStats.totalEpisodes) downloaded episodes and free up \(viewModel.storageStats.formattedTotal). This action cannot be undone.")
        }
    }
}

// MARK: - Storage Summary Row

private struct StorageSummaryRow: View {
    let stats: StorageStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(.blue)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.formattedTotal)
                        .font(.title.bold())
                    Text("\(stats.totalEpisodes) episode\(stats.totalEpisodes == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if stats.totalGigabytes > 0.1 {
                StorageBar(stats: stats)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Storage Bar

private struct StorageBar: View {
    let stats: StorageStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    // Foreground (filled portion)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(storageColor)
                        .frame(width: geometry.size.width * storagePercentage)
                }
            }
            .frame(height: 8)

            Text("About \(String(format: "%.1f", stats.totalGigabytes)) GB used")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var storagePercentage: CGFloat {
        // Assume 64 GB device storage for visualization purposes
        // In production, we'd get actual device storage capacity
        let totalDeviceGB = 64.0
        return CGFloat(min(stats.totalGigabytes / totalDeviceGB, 1.0))
    }

    private var storageColor: Color {
        if storagePercentage > 0.9 {
            return .red
        } else if storagePercentage > 0.7 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Podcast Storage Row

private struct PodcastStorageRow: View {
    let info: PodcastStorageInfo

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Podcast Icon
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)

            // Podcast Info
            VStack(alignment: .leading, spacing: 4) {
                Text(info.podcastTitle)
                    .font(.body)
                    .lineLimit(1)

                Text("\(info.episodeCount) episode\(info.episodeCount == 1 ? "" : "s") • \(info.formattedSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Storage Size (right-aligned)
            Text(info.formattedSize)
                .font(.callout.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("With Downloads") {
    NavigationStack {
        StorageManagementView()
    }
}

#Preview("Empty State") {
    NavigationStack {
        StorageManagementView()
    }
}

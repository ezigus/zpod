import CoreModels
import SwiftUI

// MARK: - ListeningHistoryTimelineView

/// Scrollable list of history entries grouped by calendar day, most recent first.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ListeningHistoryTimelineView: View {
    let viewModel: ListeningHistoryViewModel

    var body: some View {
        if viewModel.filteredEntries.isEmpty {
            ListeningHistoryEmptyState(
                systemImage: "clock.badge.xmark",
                title: "No History",
                message: "Episodes you finish listening to will appear here."
            )
        } else {
            List {
                ForEach(viewModel.entriesByDay, id: \.day) { group in
                    Section(group.day) {
                        ForEach(group.entries) { entry in
                            HistoryEntryRow(entry: entry)
                                .accessibilityIdentifier("ListeningHistory.Entry.\(entry.id)")
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel.deleteEntry(id: group.entries[index].id)
                            }
                        }
                    }
                }
            }
            #if os(iOS) || os(visionOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.plain)
            #endif
        }
    }
}

// MARK: - HistoryEntryRow

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct HistoryEntryRow: View {
    let entry: PlaybackHistoryEntry

    private var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: entry.duration) ?? "--"
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: entry.playedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.episodeTitle ?? "Unknown Episode")
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                if entry.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                }
            }

            if let podcastTitle = entry.podcastTitle, !podcastTitle.isEmpty {
                Text(podcastTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label(formattedDuration, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(formattedTime, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !entry.completed {
                    Text("In Progress")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ListeningHistoryEmptyState

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ListeningHistoryEmptyState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }
}

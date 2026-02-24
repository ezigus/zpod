import CoreModels
import SwiftUI

// MARK: - ListeningHistorySearchView

/// Text search + date range + completion filter over listening history entries.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct ListeningHistorySearchView: View {
    var viewModel: ListeningHistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            VStack(spacing: 8) {
                Picker("Date Range", selection: $viewModel.selectedDays) {
                    Text("Last 7 days").tag(Optional<Int>(7))
                    Text("Last 30 days").tag(Optional<Int>(30))
                    Text("Last 90 days").tag(Optional<Int>(90))
                    Text("All Time").tag(Optional<Int>(nil))
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("ListeningHistory.Search.DateRangePicker")

                Picker("Completion", selection: $viewModel.completionFilter) {
                    Text("All").tag(Optional<Bool>(nil))
                    Text("Completed").tag(Optional<Bool>(true))
                    Text("In Progress").tag(Optional<Bool>(false))
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("ListeningHistory.Search.CompletionPicker")
            }
            .padding()
            .background(.regularMaterial)

            if viewModel.filteredEntries.isEmpty {
                ListeningHistoryEmptyState(
                    systemImage: "magnifyingglass",
                    title: "No Results",
                    message: viewModel.searchQuery.isEmpty
                        ? "No episodes match the selected filters."
                        : "No episodes matching \"\(viewModel.searchQuery)\""
                )
            } else {
                List {
                    ForEach(viewModel.filteredEntries) { entry in
                        HistoryEntryRow(entry: entry)
                            .accessibilityIdentifier("ListeningHistory.Search.Entry.\(entry.id)")
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $viewModel.searchQuery, prompt: "Search episodes or podcasts")
    }
}

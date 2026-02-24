import CoreModels
import Persistence
import SwiftUI

// MARK: - ListeningHistoryDashboard

/// Main listening history view with tabbed interface (Stats / Timeline / Search).
///
/// Entry point: NavigationLink from the Library tab's section header.
/// Constructed with production Persistence repositories; tests can inject mocks.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct ListeningHistoryDashboard: View {

    @State private var viewModel: ListeningHistoryViewModel
    @State private var selectedTab: HistoryTab = .stats
    @State private var showingExportSheet = false
    @State private var exportError: String?
    @State private var exportURL: URL?
    @State private var showingDeleteConfirmation = false

    public init(
        repository: any ListeningHistoryRepository = UserDefaultsListeningHistoryRepository(),
        privacySettings: any ListeningHistoryPrivacyProvider = UserDefaultsListeningHistoryPrivacySettings()
    ) {
        _viewModel = State(initialValue: ListeningHistoryViewModel(
            repository: repository,
            privacySettings: privacySettings
        ))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !viewModel.isRecordingEnabled {
                    RecordingDisabledBanner()
                }

                Picker("View", selection: $selectedTab) {
                    ForEach(HistoryTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .accessibilityIdentifier("ListeningHistory.TabPicker")

                switch selectedTab {
                case .stats:
                    ListeningHistoryStatsView(viewModel: viewModel)
                case .timeline:
                    ListeningHistoryTimelineView(viewModel: viewModel)
                case .search:
                    ListeningHistorySearchView(viewModel: viewModel)
                }
            }
            .navigationTitle("Listening History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            exportHistory(format: .json)
                        } label: {
                            Label("Export as JSON", systemImage: "arrow.up.doc")
                        }
                        .accessibilityIdentifier("ListeningHistory.ExportJSON")

                        Button {
                            exportHistory(format: .csv)
                        } label: {
                            Label("Export as CSV", systemImage: "tablecells")
                        }
                        .accessibilityIdentifier("ListeningHistory.ExportCSV")

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete All History", systemImage: "trash")
                        }
                        .accessibilityIdentifier("ListeningHistory.DeleteAll")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("ListeningHistory.MoreMenu")
                }
            }
            .onAppear { viewModel.loadHistory() }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareLink(
                        item: url,
                        subject: Text("Listening History"),
                        message: Text("Exported listening history from zPod.")
                    )
                }
            }
            .alert("Delete All History?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteAllEntries()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all listening history entries.")
            }
        }
    }

    private func exportHistory(format: ListeningHistoryExportFormat) {
        do {
            let data = try viewModel.exportData(format: format)
            let ext = format == .json ? "json" : "csv"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("listening_history.\(ext)")
            try data.write(to: url)
            exportURL = url
            showingExportSheet = true
            exportError = nil
        } catch {
            exportError = error.localizedDescription
        }
    }
}

// MARK: - HistoryTab

enum HistoryTab: String, CaseIterable, Identifiable {
    case stats, timeline, search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stats: return "Stats"
        case .timeline: return "Timeline"
        case .search: return "Search"
        }
    }
}

// MARK: - RecordingDisabledBanner

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct RecordingDisabledBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pause.circle")
                .foregroundStyle(.orange)
            Text("Listening history recording is paused in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
        .accessibilityIdentifier("ListeningHistory.RecordingDisabledBanner")
    }
}

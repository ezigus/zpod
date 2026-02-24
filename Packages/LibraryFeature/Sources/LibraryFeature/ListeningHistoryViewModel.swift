import CoreModels
import Foundation
import Persistence

// MARK: - ListeningHistoryViewModel

/// State management for the Listening History dashboard.
///
/// Owns all mutable filter/search state and caches computed statistics
/// so views never call the repository directly. Data is fetched once on
/// `loadHistory()` and refreshed when the user changes filters.
@MainActor
@Observable
public final class ListeningHistoryViewModel {

    // MARK: - Observable State

    /// Entries matching the current filter (search + date range + completion filter).
    public private(set) var filteredEntries: [PlaybackHistoryEntry] = []

    /// All history entries loaded from the repository (unfiltered).
    public private(set) var allEntries: [PlaybackHistoryEntry] = []

    /// Aggregated statistics for the current filter window.
    public private(set) var statistics: ListeningStatistics = .empty

    /// Insights derived from listening patterns.
    public private(set) var insights: [ListeningInsight] = []

    /// Whether the history dashboard is still loading data.
    public private(set) var isLoading = false

    /// Whether listening history recording is currently enabled.
    public private(set) var isRecordingEnabled = true

    // MARK: - Filter State

    /// Freetext query filtering on episode title or podcast name.
    public var searchQuery = "" {
        didSet { applyFilters() }
    }

    /// Number of recent days to include (nil = all time).
    public var selectedDays: Int? = 30 {
        didSet { loadHistory() }
    }

    /// Completion filter: nil = all, true = completed only, false = in-progress only.
    public var completionFilter: Bool? = nil {
        didSet { applyFilters() }
    }

    // MARK: - Dependencies

    private let repository: any ListeningHistoryRepository
    private let privacySettings: any ListeningHistoryPrivacyProvider

    // MARK: - Initialization

    public init(
        repository: any ListeningHistoryRepository,
        privacySettings: any ListeningHistoryPrivacyProvider
    ) {
        self.repository = repository
        self.privacySettings = privacySettings
    }

    // MARK: - Public API

    /// Load (or reload) history entries and statistics from the repository.
    /// Call from `.onAppear` on the dashboard.
    public func loadHistory() {
        isLoading = true
        isRecordingEnabled = privacySettings.isListeningHistoryEnabled()

        let filter = makeFilter()
        allEntries = repository.entries(matching: filter)
        statistics = repository.statistics(matching: filter)
        insights = repository.insights()
        applyFilters()
        isLoading = false
    }

    /// Delete a single history entry by ID and reload.
    public func deleteEntry(id: String) {
        repository.deleteEntry(id: id)
        loadHistory()
    }

    /// Delete all history entries and reload.
    public func deleteAllEntries() {
        repository.deleteAll()
        loadHistory()
    }

    /// Export the current history in the given format.
    /// Returns the exported `Data` or throws on encoding failure.
    public func exportData(format: ListeningHistoryExportFormat) throws -> Data {
        try repository.exportData(format: format)
    }

    // MARK: - Convenience

    /// Entries grouped by calendar day (most recent day first).
    public var entriesByDay: [(day: String, entries: [PlaybackHistoryEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            Self.dayFormatter.string(from: entry.playedAt)
        }
        return grouped.map { (day: $0.key, entries: $0.value.sorted { $0.playedAt > $1.playedAt }) }
            .sorted { $0.day > $1.day }
    }

    /// Total listening time formatted for display (e.g. "4h 12m").
    public var formattedTotalTime: String {
        Self.durationFormatter.string(from: statistics.totalListeningTime) ?? "0m"
    }

    /// Completion rate as a display percentage string (e.g. "74%").
    public var formattedCompletionRate: String {
        "\(Int(statistics.completionRate * 100))%"
    }

    /// Daily average listening time formatted for display.
    public var formattedDailyAverage: String {
        guard statistics.dailyAverage > 0 else { return "0m" }
        return Self.durationFormatter.string(from: statistics.dailyAverage) ?? "0m"
    }

    // MARK: - Private

    private func makeFilter() -> ListeningHistoryFilter {
        if let days = selectedDays {
            return .lastDays(days)
        }
        return ListeningHistoryFilter()
    }

    private func applyFilters() {
        var result = allEntries

        // Completion filter:
        if let completed = completionFilter {
            result = result.filter { $0.completed == completed }
        }

        // Text search (case-insensitive, matches title or podcast):
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { entry in
                (entry.episodeTitle?.lowercased().contains(q) ?? false)
                    || (entry.podcastTitle?.lowercased().contains(q) ?? false)
            }
        }

        filteredEntries = result.sorted { $0.playedAt > $1.playedAt }
    }

    // MARK: - Formatters (shared instances)

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }()
}

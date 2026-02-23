import Foundation

// MARK: - Listening History Filter

/// Filter criteria for querying listening history entries.
public struct ListeningHistoryFilter: Sendable {
    public let podcastId: String?
    public let startDate: Date?
    public let endDate: Date?
    public let completedOnly: Bool

    public init(
        podcastId: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        completedOnly: Bool = false
    ) {
        self.podcastId = podcastId
        self.startDate = startDate
        self.endDate = endDate
        self.completedOnly = completedOnly
    }

    /// Convenience filter for the last N days.
    public static func lastDays(_ days: Int) -> ListeningHistoryFilter {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        return ListeningHistoryFilter(startDate: start)
    }
}

// MARK: - Listening Statistics

/// Aggregated listening statistics computed from history entries.
public struct ListeningStatistics: Sendable, Equatable {
    /// Total listening time in seconds.
    public let totalListeningTime: TimeInterval
    /// Number of episodes where playback was started.
    public let episodesStarted: Int
    /// Number of episodes marked as completed.
    public let episodesCompleted: Int
    /// Completion rate as a fraction 0.0–1.0.
    public let completionRate: Double
    /// Current consecutive-day listening streak.
    public let currentStreak: Int
    /// Longest consecutive-day listening streak ever recorded.
    public let longestStreak: Int
    /// Top podcasts by listening time (podcastId -> total seconds).
    public let topPodcasts: [(podcastId: String, podcastTitle: String, totalTime: TimeInterval)]
    /// Average daily listening time over the queried period.
    public let dailyAverage: TimeInterval

    public init(
        totalListeningTime: TimeInterval,
        episodesStarted: Int,
        episodesCompleted: Int,
        completionRate: Double,
        currentStreak: Int,
        longestStreak: Int,
        topPodcasts: [(podcastId: String, podcastTitle: String, totalTime: TimeInterval)],
        dailyAverage: TimeInterval
    ) {
        self.totalListeningTime = totalListeningTime
        self.episodesStarted = episodesStarted
        self.episodesCompleted = episodesCompleted
        self.completionRate = completionRate
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.topPodcasts = topPodcasts
        self.dailyAverage = dailyAverage
    }

    /// Empty statistics for when no history exists.
    public static let empty = ListeningStatistics(
        totalListeningTime: 0,
        episodesStarted: 0,
        episodesCompleted: 0,
        completionRate: 0,
        currentStreak: 0,
        longestStreak: 0,
        topPodcasts: [],
        dailyAverage: 0
    )

    public static func == (lhs: ListeningStatistics, rhs: ListeningStatistics) -> Bool {
        lhs.totalListeningTime == rhs.totalListeningTime
            && lhs.episodesStarted == rhs.episodesStarted
            && lhs.episodesCompleted == rhs.episodesCompleted
            && lhs.completionRate == rhs.completionRate
            && lhs.currentStreak == rhs.currentStreak
            && lhs.longestStreak == rhs.longestStreak
            && lhs.dailyAverage == rhs.dailyAverage
            && lhs.topPodcasts.count == rhs.topPodcasts.count
    }
}

// MARK: - Listening Insight

/// A human-readable insight derived from listening patterns.
public struct ListeningInsight: Sendable, Identifiable {
    public let id: UUID
    public let text: String
    public let systemImage: String

    public init(id: UUID = UUID(), text: String, systemImage: String) {
        self.id = id
        self.text = text
        self.systemImage = systemImage
    }
}

// MARK: - Export Format

/// Supported export formats for listening history data.
public enum ListeningHistoryExportFormat: Sendable {
    case json
    case csv
}

// MARK: - Listening History Repository Protocol

/// Repository for recording, querying, and exporting listening history.
///
/// Lives in CoreModels so feature modules can depend on the protocol without
/// pulling in Persistence. The concrete `UserDefaultsListeningHistoryRepository`
/// lives in the Persistence package.
public protocol ListeningHistoryRepository: Sendable {
    // MARK: Record
    func record(_ entry: PlaybackHistoryEntry)

    // MARK: Query
    func entries(matching filter: ListeningHistoryFilter) -> [PlaybackHistoryEntry]
    func allEntries() -> [PlaybackHistoryEntry]

    // MARK: Delete
    func deleteEntry(id: String)
    func deleteAll()

    // MARK: Statistics
    func statistics(matching filter: ListeningHistoryFilter) -> ListeningStatistics
    func insights() -> [ListeningInsight]

    // MARK: Export
    func exportData(format: ListeningHistoryExportFormat) throws -> Data

    // MARK: Maintenance
    func pruneOldEntries()
}

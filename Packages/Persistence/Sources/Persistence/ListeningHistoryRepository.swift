import CoreModels
import Foundation

// MARK: - UserDefaultsListeningHistoryRepository

/// Stores listening history entries in UserDefaults with a 180-day rolling window.
///
/// Thread-safety: protected by `NSLock`; safe to call from any thread.
/// Mirrors the pattern of `UserDefaultsSmartPlaylistAnalyticsRepository`.
public final class UserDefaultsListeningHistoryRepository: ListeningHistoryRepository, @unchecked Sendable {

    private static let storageKey = "listening_history_entries"
    private static let retentionDays: Int = 180

    private let userDefaults: UserDefaults
    private let lock = NSLock()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Record

    public func record(_ entry: PlaybackHistoryEntry) {
        lock.withLock {
            var all = loadAll()
            all.append(entry)
            pruneAll(&all)
            saveAll(all)
        }
    }

    // MARK: - Query

    public func entries(matching filter: ListeningHistoryFilter) -> [PlaybackHistoryEntry] {
        lock.withLock {
            applyFilter(filter, to: loadAll())
        }
    }

    public func allEntries() -> [PlaybackHistoryEntry] {
        lock.withLock { loadAll() }
    }

    // MARK: - Delete

    public func deleteEntry(id: String) {
        lock.withLock {
            var all = loadAll()
            all.removeAll { $0.id == id }
            saveAll(all)
        }
    }

    public func deleteAll() {
        lock.withLock {
            userDefaults.removeObject(forKey: Self.storageKey)
        }
    }

    // MARK: - Statistics

    public func statistics(matching filter: ListeningHistoryFilter) -> ListeningStatistics {
        let filtered = entries(matching: filter)
        guard !filtered.isEmpty else { return .empty }

        let totalTime = filtered.reduce(0.0) { $0 + $1.duration }
        let started = filtered.count
        let completed = filtered.filter(\.completed).count
        let rate = started > 0 ? Double(completed) / Double(started) : 0

        // Streak calculation
        let calendar = Calendar.current
        let sortedDates = Set(filtered.map { calendar.startOfDay(for: $0.playedAt) }).sorted(by: >)
        let (current, longest) = computeStreaks(sortedDates: sortedDates, calendar: calendar)

        // Top podcasts by listening time
        var podcastTimes: [String: (title: String, time: TimeInterval)] = [:]
        for entry in filtered {
            let key = entry.podcastId
            let existing = podcastTimes[key] ?? (title: entry.podcastTitle ?? key, time: 0)
            podcastTimes[key] = (title: entry.podcastTitle ?? existing.title, time: existing.time + entry.duration)
        }
        let topPodcasts = podcastTimes
            .sorted { $0.value.time > $1.value.time }
            .prefix(10)
            .map { (podcastId: $0.key, podcastTitle: $0.value.title, totalTime: $0.value.time) }

        // Daily average
        let dayCount = max(sortedDates.count, 1)
        let dailyAvg = totalTime / Double(dayCount)

        return ListeningStatistics(
            totalListeningTime: totalTime,
            episodesStarted: started,
            episodesCompleted: completed,
            completionRate: rate,
            currentStreak: current,
            longestStreak: longest,
            topPodcasts: topPodcasts,
            dailyAverage: dailyAvg
        )
    }

    public func insights() -> [ListeningInsight] {
        let stats = statistics(matching: ListeningHistoryFilter())
        var result: [ListeningInsight] = []

        if stats.episodesStarted == 0 {
            result.append(ListeningInsight(
                text: "No listening history recorded yet.",
                systemImage: "play.slash"
            ))
            return result
        }

        // Total time insight
        let hours = stats.totalListeningTime / 3600
        if hours >= 1 {
            result.append(ListeningInsight(
                text: String(format: "%.1f hours of listening in the last 180 days.", hours),
                systemImage: "clock.fill"
            ))
        } else {
            let minutes = stats.totalListeningTime / 60
            result.append(ListeningInsight(
                text: String(format: "%.0f minutes of listening so far.", minutes),
                systemImage: "clock"
            ))
        }

        // Episodes insight
        result.append(ListeningInsight(
            text: "\(stats.episodesStarted) episode\(stats.episodesStarted == 1 ? "" : "s") started, \(stats.episodesCompleted) completed.",
            systemImage: "play.fill"
        ))

        // Completion rate
        if stats.episodesStarted >= 3 {
            let pct = Int(stats.completionRate * 100)
            result.append(ListeningInsight(
                text: "\(pct)% completion rate.",
                systemImage: "checkmark.circle"
            ))
        }

        // Streak
        if stats.currentStreak >= 2 {
            result.append(ListeningInsight(
                text: "\(stats.currentStreak)-day listening streak!",
                systemImage: "flame.fill"
            ))
        }

        // Top podcast
        if let top = stats.topPodcasts.first {
            let topHours = top.totalTime / 3600
            if topHours >= 1 {
                result.append(ListeningInsight(
                    text: String(format: "Most listened: %@ (%.1f hours).", top.podcastTitle, topHours),
                    systemImage: "star.fill"
                ))
            }
        }

        return result
    }

    // MARK: - Export

    public func exportData(format: ListeningHistoryExportFormat) throws -> Data {
        let all = allEntries()
        switch format {
        case .json:
            return try exportJSON(all)
        case .csv:
            return exportCSV(all)
        }
    }

    // MARK: - Maintenance

    public func pruneOldEntries() {
        lock.withLock {
            var all = loadAll()
            pruneAll(&all)
            saveAll(all)
        }
    }

    // MARK: - Private Helpers

    private func loadAll() -> [PlaybackHistoryEntry] {
        guard let data = userDefaults.data(forKey: Self.storageKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([PlaybackHistoryEntry].self, from: data)) ?? []
    }

    private func saveAll(_ entries: [PlaybackHistoryEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries) {
            userDefaults.set(data, forKey: Self.storageKey)
        }
    }

    private func pruneAll(_ entries: inout [PlaybackHistoryEntry]) {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -Self.retentionDays,
            to: Date()
        ) ?? Date()
        entries = entries.filter { $0.playedAt >= cutoff }
    }

    private func applyFilter(_ filter: ListeningHistoryFilter, to entries: [PlaybackHistoryEntry]) -> [PlaybackHistoryEntry] {
        entries.filter { entry in
            if let pid = filter.podcastId, entry.podcastId != pid { return false }
            if let start = filter.startDate, entry.playedAt < start { return false }
            if let end = filter.endDate, entry.playedAt > end { return false }
            if filter.completedOnly && !entry.completed { return false }
            return true
        }
    }

    private func computeStreaks(sortedDates: [Date], calendar: Calendar) -> (current: Int, longest: Int) {
        guard !sortedDates.isEmpty else { return (0, 0) }

        var current = 1
        var longest = 1
        var streak = 1

        // Check if today (or yesterday) is in the dates for current streak
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let isCurrentActive = sortedDates.first == today || sortedDates.first == yesterday

        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i], to: sortedDates[i - 1]).day ?? 0
            if diff == 1 {
                streak += 1
                longest = max(longest, streak)
            } else {
                if i == 1 || streak > 1 {
                    // First break ends the current streak calculation
                }
                streak = 1
            }
            if i == 1 { current = streak }
        }

        // For single-element or full pass
        if sortedDates.count == 1 { current = 1 }
        else { current = min(current, streak == sortedDates.count ? streak : current) }

        // Recalculate current streak from most recent date
        current = 1
        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i], to: sortedDates[i - 1]).day ?? 0
            if diff == 1 {
                current += 1
            } else {
                break
            }
        }
        longest = max(longest, current)

        if !isCurrentActive { current = 0 }

        return (current, longest)
    }

    private func exportJSON(_ entries: [PlaybackHistoryEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }

    private func exportCSV(_ entries: [PlaybackHistoryEntry]) -> Data {
        var lines: [String] = ["id,episodeId,podcastId,episodeTitle,podcastTitle,playedAt,duration,completed,playbackSpeed"]
        let formatter = ISO8601DateFormatter()
        for entry in entries {
            let title = csvEscape(entry.episodeTitle ?? "")
            let podTitle = csvEscape(entry.podcastTitle ?? "")
            let speed = entry.playbackSpeed.map { String($0) } ?? ""
            let line = "\(entry.id),\(entry.episodeId),\(entry.podcastId),\(title),\(podTitle),\(formatter.string(from: entry.playedAt)),\(entry.duration),\(entry.completed),\(speed)"
            lines.append(line)
        }
        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

import CoreModels
import Foundation

// MARK: - UserDefaultsSmartPlaylistAnalyticsRepository

/// Stores play events in UserDefaults with a 90-day rolling window.
///
/// Events are persisted as a flat JSON array across all playlists — one key for the whole store.
/// `pruneOldEvents()` is called automatically on each `record(_:)` call so the store
/// never grows unbounded.
///
/// Thread-safety: protected by `NSLock`; safe to call from any thread.
public final class UserDefaultsSmartPlaylistAnalyticsRepository: SmartPlaylistAnalyticsRepository, @unchecked Sendable {

    private static let storageKey = "smart_playlist_analytics_events"
    private static let retentionDays: Int = 90

    private let userDefaults: UserDefaults
    private let lock = NSLock()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Record

    public func record(_ event: SmartPlaylistPlayEvent) {
        lock.withLock {
            var all = loadAll()
            all.append(event)
            pruneAll(&all)
            saveAll(all)
        }
    }

    // MARK: - Query

    public func events(for playlistID: String) -> [SmartPlaylistPlayEvent] {
        lock.withLock {
            loadAll().filter { $0.playlistID == playlistID }
        }
    }

    public func stats(for playlistID: String) -> SmartPlaylistStats {
        let filtered = events(for: playlistID)
        guard !filtered.isEmpty else {
            return SmartPlaylistStats.empty(for: playlistID)
        }
        let uniqueEpisodes = Set(filtered.map(\.episodeID)).count
        let totalDuration = filtered.compactMap(\.episodeDuration).reduce(0, +)
        let mostRecent = filtered.map(\.occurredAt).max()
        return SmartPlaylistStats(
            playlistID: playlistID,
            totalPlays: filtered.count,
            uniqueEpisodesPlayed: uniqueEpisodes,
            totalPlaybackDuration: totalDuration,
            mostRecentPlay: mostRecent
        )
    }

    public func insights(for playlistID: String) -> [SmartPlaylistInsight] {
        let playlistStats = stats(for: playlistID)
        var result: [SmartPlaylistInsight] = []

        if playlistStats.totalPlays == 0 {
            result.append(SmartPlaylistInsight(
                text: "No episodes have been played from this playlist yet.",
                systemImage: "play.slash"
            ))
            return result
        }

        result.append(SmartPlaylistInsight(
            text: "\(playlistStats.totalPlays) episode\(playlistStats.totalPlays == 1 ? "" : "s") played in the last 90 days.",
            systemImage: "play.fill"
        ))

        if playlistStats.uniqueEpisodesPlayed > 1 {
            result.append(SmartPlaylistInsight(
                text: "\(playlistStats.uniqueEpisodesPlayed) unique episodes discovered through this playlist.",
                systemImage: "sparkles"
            ))
        }

        if playlistStats.totalPlaybackDuration >= 3600 {
            let hours = playlistStats.totalPlaybackDuration / 3600
            result.append(SmartPlaylistInsight(
                text: String(format: "%.1f hours of listening driven by this playlist.", hours),
                systemImage: "clock.fill"
            ))
        }

        if let recent = playlistStats.mostRecentPlay {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let rel = formatter.localizedString(for: recent, relativeTo: Date())
            result.append(SmartPlaylistInsight(
                text: "Last played \(rel).",
                systemImage: "calendar"
            ))
        }

        return result
    }

    public func exportJSON(for playlistID: String) throws -> Data {
        let filtered = events(for: playlistID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(filtered)
    }

    // MARK: - Pruning

    public func pruneOldEvents() {
        lock.withLock {
            var all = loadAll()
            pruneAll(&all)
            saveAll(all)
        }
    }

    // MARK: - Private

    private func loadAll() -> [SmartPlaylistPlayEvent] {
        guard let data = userDefaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SmartPlaylistPlayEvent].self, from: data)
        else { return [] }
        return decoded
    }

    private func saveAll(_ events: [SmartPlaylistPlayEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            userDefaults.set(data, forKey: Self.storageKey)
        }
    }

    private func pruneAll(_ events: inout [SmartPlaylistPlayEvent]) {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -Self.retentionDays,
            to: Date()
        ) ?? Date()
        events = events.filter { $0.occurredAt >= cutoff }
    }
}

import CoreModels
import Foundation
import SharedUtilities

// MARK: - UserDefaultsSmartPlaylistAnalyticsRepository

/// Stores play events in UserDefaults with a 90-day rolling window.
///
/// Events are persisted as a flat JSON array across all playlists — one key for the whole store.
/// `pruneOldEvents()` is called automatically on each `record(_:)` call so the store
/// never grows unbounded.
///
/// Thread-safety: protected by a class-level `NSLock` shared across all instances.
///
/// A per-instance lock is insufficient because two separate instances backed by the same
/// `UserDefaults` store (e.g. both using `.standard`) would perform non-atomic
/// read-modify-write cycles concurrently, silently dropping events. The static lock
/// serialises every mutation regardless of how many instances exist.
public final class UserDefaultsSmartPlaylistAnalyticsRepository: SmartPlaylistAnalyticsRepository, @unchecked Sendable {

    private static let storageKey = "smart_playlist_analytics_events"
    // Shared across ALL instances — prevents lost-update races when two instances
    // operate on the same underlying UserDefaults store simultaneously.
    // NSLock is Sendable, so no isolation annotation is needed.
    //
    // Design trade-off: a static lock serialises unrelated stores if callers use
    // different UserDefaults suites. This is acceptable because (a) all current
    // callers target `.standard`, and (b) the critical section is sub-millisecond
    // (JSON encode/decode), so contention cost is negligible.
    private static let lock = NSLock()

    private let userDefaults: UserDefaults
    private let retentionDays: Int
    private let maxEventCount: Int
    private let currentDate: @Sendable () -> Date

    public init(
        userDefaults: UserDefaults = .standard,
        retentionDays: Int = 90,
        maxEventCount: Int = 5000,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        precondition(maxEventCount >= 1, "maxEventCount must be at least 1")
        self.userDefaults = userDefaults
        self.retentionDays = retentionDays
        self.maxEventCount = maxEventCount
        self.currentDate = currentDate
    }

    // MARK: - Record

    public func record(_ event: SmartPlaylistPlayEvent) {
        Self.lock.withLock {
            var all = loadAll()
            all.append(event)
            pruneAll(&all)
            if !saveAll(all) {
                Logger.error("SmartPlaylistAnalyticsRepository: event for playlist '\(event.playlistID)' was not persisted due to encoding failure")
            }
        }
    }

    // MARK: - Query

    public func events(for playlistID: String) -> [SmartPlaylistPlayEvent] {
        Self.lock.withLock {
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
        // Use .sortedKeys only (no .prettyPrinted) to keep output compact.
        // With the 5000-event cap the filtered set could reach ~1MB pretty-printed;
        // compact JSON keeps that well under 300 KB and avoids allocation spikes.
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(filtered)
    }

    // MARK: - Pruning

    public func pruneOldEvents() {
        Self.lock.withLock {
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

    @discardableResult
    private func saveAll(_ events: [SmartPlaylistPlayEvent]) -> Bool {
        do {
            let data = try JSONEncoder().encode(events)
            userDefaults.set(data, forKey: Self.storageKey)
            return true
        } catch {
            Logger.error("SmartPlaylistAnalyticsRepository: failed to encode \(events.count) events — \(error.localizedDescription)")
            return false
        }
    }

    private func pruneAll(_ events: inout [SmartPlaylistPlayEvent]) {
        let now = currentDate()
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: now
        ) ?? now
        events = events.filter { $0.occurredAt >= cutoff }

        // Hard cap prevents unbounded UserDefaults growth
        if events.count > maxEventCount {
            let discardCount = events.count - maxEventCount
            events.sort { $0.occurredAt > $1.occurredAt }
            events = Array(events.prefix(maxEventCount))
            Logger.debug("SmartPlaylistAnalyticsRepository: pruned \(discardCount) oldest events to stay within \(maxEventCount) cap")
        }
    }
}

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

    // MARK: - Thread Safety
    // This class is marked @unchecked Sendable because NSLock serialises all mutations.
    // Invariant: `currentDate` must capture no mutable state or `self` references —
    // it is either `{ Date() }` or a pure deterministic closure (e.g. for testing).
    // If this invariant ever breaks, the @unchecked Sendable marking will hide the violation.
    private let userDefaults: UserDefaults
    private let retentionDays: Int
    private let maxEventCount: Int
    private let currentDate: @Sendable () -> Date

    /// Creates a new repository instance.
    ///
    /// - Parameters:
    ///   - userDefaults: The `UserDefaults` store to persist events in. Defaults to `.standard`.
    ///   - retentionDays: Events older than this many days are pruned. Defaults to 90.
    ///   - maxEventCount: Hard cap on stored events; oldest are pruned when exceeded. Must be ≥ 1.
    ///     Defaults to 5000. Enforced in all builds via `precondition`.
    ///   - currentDate: Clock provider injected for deterministic testing. **Invariant**: must capture
    ///     no mutable state or `self` references — it must be a pure, `@Sendable`-safe closure.
    ///     The default `{ Date() }` satisfies this invariant. Violations are not caught by the
    ///     compiler due to `@unchecked Sendable`; callers must enforce this manually.
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

    // NOTE: This encoder uses default settings (no special date strategy).
    // If you change the date encoding strategy here, also update exportJSON(for:) which
    // uses .iso8601 — both must remain consistent to avoid stored/exported format divergence.
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
        // currentDate() is assumed to return a non-decreasing value.
        // If the clock goes backwards (e.g. a system clock adjustment), pruning may retain
        // unexpected old events relative to the adjusted time, but no events are erroneously lost.
        let now = currentDate()
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: now
        ) ?? now
        events = events.filter { $0.occurredAt >= cutoff }

        // Hard cap prevents unbounded UserDefaults growth.
        // Pass 2 runs after Pass 1 (retention window), so count here reflects surviving events only.
        if events.count > maxEventCount {
            let discardCount = events.count - maxEventCount
            // Stable sort: primary key is occurredAt descending; UUID string breaks ties
            // deterministically so pruning order is reproducible when timestamps collide.
            events.sort { lhs, rhs in
                if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            events = Array(events.prefix(maxEventCount))
            // Debug log: safe even if discardCount == maxEventCount
            Logger.debug("SmartPlaylistAnalyticsRepository: pruned \(discardCount) oldest events to stay within \(maxEventCount) cap")
        }
    }
}

# Dev Log: Issue #13 — Listening History & Playback Statistics

## 2026-02-23 — Implementation (Pipeline: autonomous)

### Intent

Implement the backend data layer for listening history and playback statistics. This is infrastructure that downstream UI features will consume — no new screens in this issue.

### Design Decisions

1. **Extended `PlaybackHistoryEntry` instead of new model** — The existing struct in `RecommendationModels.swift` is already consumed by `BaselineRecommendationService`. Adding optional fields (`episodeTitle`, `podcastTitle`, `playbackSpeed`) with `nil` defaults preserves backward compatibility while enriching the data for statistics.

2. **Mirrored `SmartPlaylistAnalyticsRepository` pattern** — Protocol in CoreModels, UserDefaults+NSLock implementation in Persistence. This is the established pattern and keeps the dependency graph clean.

3. **180-day rolling window** — Longer than the 90-day window used by playlist analytics because listening history has longer-term relevance for statistics and recommendations.

4. **Observer pattern via Combine** — `ListeningHistoryRecorder` subscribes to `EpisodePlaybackService.statePublisher` and records `.finished` events. This avoids modifying the playback engine directly.

5. **Separate privacy provider** — `ListeningHistoryPrivacyProvider` protocol with `UserDefaultsListeningHistoryPrivacySettings` implementation. Kept separate from `SettingsRepository` to avoid protocol churn on a widely-consumed interface.

### Files Created/Modified

#### New Files
- `Packages/CoreModels/Sources/CoreModels/ListeningHistoryModels.swift` — Protocol, filter, statistics, insights, export format
- `Packages/CoreModels/Sources/CoreModels/ListeningHistoryPrivacySettings.swift` — Privacy provider protocol
- `Packages/Persistence/Sources/Persistence/ListeningHistoryRepository.swift` — UserDefaults repository implementation
- `Packages/Persistence/Sources/Persistence/ListeningHistoryPrivacySettings.swift` — Privacy toggle implementation
- `Packages/LibraryFeature/Sources/LibraryFeature/ListeningHistoryRecorder.swift` — Combine-based recorder
- `Packages/Persistence/Tests/PersistenceTests/ListeningHistoryRepositoryTests.swift` — 27 repository tests
- `Packages/CoreModels/Tests/CoreModelsTests/PlaybackHistoryEntryTests.swift` — 8 model tests

#### Modified Files
- `Packages/CoreModels/Sources/CoreModels/RecommendationModels.swift` — Extended `PlaybackHistoryEntry` with 3 optional fields + `Identifiable`
- `Packages/LibraryFeature/Sources/LibraryFeature/PlaybackEnvironment.swift` — Added lazy `listeningHistoryRecorder` property

### Architecture

```
EpisodePlaybackService.statePublisher
        │ (Combine .finished events)
        ▼
ListeningHistoryRecorder
        │ (checks privacy toggle)
        ▼
UserDefaultsListeningHistoryRepository
        │ (NSLock, 180-day pruning)
        ▼
    UserDefaults
```

### Test Coverage

| Test File | Tests | Scope |
|-----------|-------|-------|
| PlaybackHistoryEntryTests | 8 | Codable, backward compat, Identifiable, Equatable |
| ListeningHistoryRepositoryTests | 27 | CRUD, filter, stats, insights, pruning, export, privacy |

### Next Steps

- Issue #10.1: Build Statistics UI that consumes `ListeningHistoryRepository`
- Issue #14.1.2: Feed enriched `PlaybackHistoryEntry` data into recommendations
- Issue #24.1.1: Wire export formats into data export UI

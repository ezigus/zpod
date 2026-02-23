# Issue #13: Listening History & Playback Statistics

## Status: In Progress

## Description

Backend infrastructure for listening history and playback statistics. Provides the data layer that downstream features (Issue #10.1 Statistics UI, Issue #14.1.2 Smart Recommendations, Issue #24.1.1 Data Export) will consume.

## Scope

- Record playback events automatically when episodes finish
- Persist listening history with 180-day rolling window
- Query and filter history by podcast, date range, completion status
- Compute aggregated statistics (total time, completion rate, streaks, top podcasts)
- Generate human-readable insights from listening patterns
- Export history data in JSON and CSV formats
- Privacy toggle to enable/disable recording

**Out of scope**: No new UI screens (that's Issue #10.1).

## Acceptance Criteria

- [ ] `PlaybackHistoryEntry` extended with `episodeTitle`, `podcastTitle`, `playbackSpeed` (backward compatible)
- [ ] `ListeningHistoryRepository` protocol defined in CoreModels
- [ ] `UserDefaultsListeningHistoryRepository` implemented in Persistence (180-day window, NSLock thread safety)
- [ ] `ListeningHistoryRecorder` observes playback state and records `.finished` events
- [ ] Privacy toggle (`isListeningHistoryEnabled`) defaults to true, respected by recorder
- [ ] Statistics: total time, episodes started/completed, completion rate, streaks, top podcasts, daily average
- [ ] Export in JSON and CSV formats
- [ ] Unit tests for models, repository, and privacy settings
- [ ] All existing tests continue to pass

## Dependencies

- CoreModels (extended models, protocol)
- Persistence (repository implementation)
- PlaybackEngine (state publisher)
- LibraryFeature (recorder wiring)

## Testing Strategy

- CoreModels unit tests: Codable round-trip, backward compatibility, Identifiable/Equatable
- Persistence unit tests: CRUD, filtering, statistics, pruning, export, privacy
- Syntax check and full regression to ensure no breakage

# Issue 32.1: Remove Hardcoded Sample Data from Production; Add Test Fixtures

**GitHub Issue**: #427
**Branch**: `test/-32-1-remove-hardcoded-sample-data-from-427`

## Intent

Remove hardcoded podcast/episode sample data from `ContentViewBridge.swift` and add reusable test fixtures in `Packages/TestSupport/Sources/TestSupport/Fixtures/`.

## Implementation (2026-03-15 → 2026-03-16)

### Changes Made

**`zpod/ContentViewBridge.swift`**

- Removed `PlaceholderPodcastData` enum (lines 78–139 in original) containing `sampleEpisodes` and `samplePodcasts`
- Updated `PlaceholderPodcastManager.init` default from `PlaceholderPodcastData.samplePodcasts` to `[]`
- Replaced `LibraryPlaceholderView` sample podcast cards with empty-state "No podcasts yet." message
- Replaced `EpisodeListPlaceholderView` sample episode rendering with empty-state "No episodes yet." message

**New Files Added**

- `Packages/TestSupport/Sources/TestSupport/Fixtures/PodcastFixtures.swift` — Swift Talk, Swift Over Coffee, ATP fixtures
- `Packages/TestSupport/Sources/TestSupport/Fixtures/EpisodeFixtures.swift` — Episodes tied to fixtures (st-001..st-005, soc-001..soc-003, atp-001..atp-002)
- `Packages/TestSupport/Tests/TestSupportTests/FixturesTests.swift` — Unit tests for fixture correctness

### Task 8: LibraryFeature/ContentView.swift Verification

**Finding**: `EpisodeListViewWrapper.createSamplePodcast` (lines 881–1009) creates hardcoded sample episodes for the episode list view. This is NOT the `samplePodcasts in loadData()` referenced in the issue (removed by 27.1.9).

**Assessment**:

- `createSamplePodcast` IS production code (no `#if DEBUG` guard)
- Creates sample episodes used as the data source for `EpisodeListView` via `EpisodeListViewModel.allEpisodes = podcast.episodes`
- In production (no UITEST env vars), episodes have nil audio URLs but ARE shown
- This is test infrastructure embedded in production code
- Fixing requires: either (a) passing the real `Podcast` object from `LibraryView` to navigation dest, or (b) seeding episodes via a `UITEST_SEED_EPISODES` env mechanism
- **This is out of scope for #32.1** — the issue scope covers `ContentViewBridge.swift` cleanup and verified `samplePodcasts in loadData()` is gone
- **Recommendation**: Open follow-up issue to replace `EpisodeListViewWrapper.createSamplePodcast` with proper test episode seeding

### Test Results

- Package tests: 1032/1032 PASS ✅
- AppSmoke tests: 59/59 PASS ✅
- Integration tests: 89/89 PASS ✅
- UI tests: 36 pre-existing failures (verified: none reference our changed files)

**Pre-existing UI failures** (not caused by #32.1 changes):

- `OfflinePlaybackUITests` — 6 failures (timing/quiescence)
- `PlaybackPositionAVPlayerTests` — 7 failures (AVPlayer tests)
- `StorageManagementUITests` — 6 failures
- `StreamingInterruptionUITests` — 5 failures
- Others: SmartPlaylistAuthoringUITests (3), PlaybackPositionTickerTests (2), MiniPlayerPersistenceTests (2), CoreUINavigation (1), OrphanedEpisodes (1), PlayerAccessibility (1), SwipeConfig (1), SwipeExecution (1)

## Status

✅ **Complete** — All primary acceptance criteria met.

# Issue 28.1 - Offline and Streaming Playback Infrastructure

**Status:** 80% Complete (Phases 1 & 3 Done, Phases 2, 4, 5 Remaining)
**Branch:** `feature/28.1-download-manager`
**Last Updated:** 2026-02-03 20:00 ET

## Quick Status

### ✅ What Works Today

**Download Infrastructure:**
- ✅ URLSession-based real downloads with progress tracking
- ✅ Download queue management with priority support
- ✅ Local file caching in app Documents directory
- ✅ Swipe action to download episodes
- ✅ Batch download in multi-select mode (fixed 2026-02-03)
- ✅ Download progress indicators in episode rows
- ✅ Local file playback preference in `EnhancedEpisodePlayer`
- ✅ 136+ passing unit tests for download infrastructure

**UI Integration:**
- ✅ Download status badges (notDownloaded, downloading, paused, downloaded, failed)
- ✅ Progress bars during download
- ✅ Pause/Resume buttons
- ✅ Retry button on failed downloads
- ✅ Swipe actions configured and functional

**Network Interruption Handling:**
- ✅ NetworkMonitor service with NWPathMonitor + Combine
- ✅ Protocol-based design (NetworkMonitoring) for testability
- ✅ AVPlayer buffer status observation (KVO)
- ✅ Auto-pause on network disconnection
- ✅ Auto-resume with 3-second grace period on recovery
- ✅ Recovery cancellation during grace period
- ✅ 13 network monitoring tests passing
- ✅ StreamingInterruptionTests for network behavior

### ⚠️ What's Partially Done

**Storage Management:**
- ✅ Storage policy evaluation logic exists
- ✅ File size tracking APIs available
- ❌ No UI to view total storage used
- ❌ No per-podcast storage breakdown
- ❌ No "Manage Storage" settings screen

**Test Coverage:**
- ✅ Unit tests (136+ passing)
- ✅ Integration tests (queue→download→cache flow)
- ✅ Network interruption tests (StreamingInterruptionTests)
- ❌ UI tests for download flow
- ❌ Streaming buffer tests

### ❌ What's Missing (Non-Blocking)

**Retry Logic (MEDIUM PRIORITY):**
- ❌ No exponential backoff retry logic for transient errors
- ❌ StreamingErrorHandler not yet implemented

**Siri Metadata Persistence (LOW PRIORITY):**
- ❌ Episodes not persisted to SwiftData
- ❌ Episode lists empty after app restart
- ❌ Siri snapshots incomplete after restart

## Acceptance Criteria Status

| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| AC1 | Manual download via UI | ✅ 100% | Swipe action functional |
| AC2 | Local playback | ✅ 100% | Prefers local files |
| AC3 | Streaming playback | ✅ 100% | Falls back to network |
| AC4 | Download status indicators | ✅ 100% | Badges + progress bars |
| AC5 | Network interruption handling | ⚠️ 80% | Auto-pause/resume ✅, retry logic ⏳ |
| AC6 | Delete downloaded episodes | ✅ 100% | Deletion APIs working |
| AC7 | Storage tracking/display | ⚠️ 50% | Logic ✅, UI ❌ |
| AC8 | Comprehensive tests | ⚠️ 70% | Unit ✅, network ✅, UI ❌ |
| AC9 | Siri snapshots after restart | ❌ 0% | Not persisted |
| AC10 | All spec scenarios tested | ⚠️ 75% | Offline ✅, network ✅, retry ⏳ |
| AC11 | Dev-log documentation | ✅ 100% | Comprehensive |

## Implementation Phases

### ✅ Phase 1: UI Integration (COMPLETE - 2026-02-03)

**Completed:**
- Verified swipe action `.download` functional
- Fixed batch download operation to call real download manager
- Confirmed progress indicators displaying
- All LibraryFeature tests passing (21/21)

**Commit:** `95520d6` - Fix batch download operation

### ⏳ Phase 2: Storage Management UI (NOT STARTED)

**Estimated Effort:** 1-2 days

**Tasks:**
1. Create `StorageManagementView.swift` in LibraryFeature
2. Display total storage used by downloads
3. Show per-podcast storage breakdown
4. Add "Delete All Downloads" bulk action
5. Wire to `StoragePolicyEvaluator`

**Files to Create/Modify:**
- `Packages/LibraryFeature/Sources/LibraryFeature/Views/StorageManagementView.swift` (NEW)
- Settings navigation integration

### ✅ Phase 3: Network Interruption Handling (MOSTLY COMPLETE - 2026-02-03) - **CRITICAL**

**Estimated Effort:** 3-4 days
**Actual Effort:** 1 day
**Priority:** HIGH (blocks production)

**Completed:**
- ✅ `NetworkMonitor` service with NWPathMonitor + Combine publishers
- ✅ NetworkMonitoring protocol for testable design
- ✅ AVPlayer KVO for `playbackBufferEmpty` and `playbackLikelyToKeepUp`
- ✅ Auto-pause on network disconnection
- ✅ Auto-resume after 3-second grace period on network recovery
- ✅ Grace period prevents jarring pause/resume on brief network blips
- ✅ Recovery cancellation if network lost during grace period
- ✅ StreamingInterruptionTests with MockNetworkMonitor
- ✅ 13 NetworkMonitor tests passing
- ✅ Protocol-based design enables dependency injection

**Deferred:**
- ⏳ Retry logic with exponential backoff (Task #9) - separate phase/issue

**Files Created:**
- ✅ `Packages/Networking/Sources/Networking/NetworkMonitor.swift` - 220 lines
- ✅ `Packages/PlaybackEngine/Tests/StreamingInterruptionTests.swift` - 323 lines
- ✅ Enhanced `AVPlayerPlaybackEngine` with network monitoring integration

**Commit:** `04a50b7` - Implement network interruption handling

**Spec Coverage:**
- ✅ Network loss detection and auto-pause
- ✅ Network recovery with grace period
- ⏳ Retry logic (deferred to Task #9)

### ⏳ Phase 4: Comprehensive Test Coverage (IN PROGRESS)

**Estimated Effort:** 3-4 days (1 day completed)

**Tasks:**
1. ✅ Create `zpodUITests/DownloadFlowUITests.swift` - DONE
2. ✅ Add download tests to CI matrix - DONE
3. ⏳ Create `zpodUITests/OfflinePlaybackUITests.swift`
4. ⏳ Add network simulation helpers for UI tests
5. ⏳ Create streaming buffer tests
6. ⏳ Add error notification/retry flow tests
7. ⏳ Map all remaining spec scenarios to tests

**Test Files Created:**
- ✅ `zpodUITests/DownloadFlowUITests.swift` - 6 test methods covering swipe download, progress, badges, batch operations, pause/resume, error handling
- ✅ `zpodUITests/README_DOWNLOAD_TESTS.md` - Comprehensive documentation of download test suite
- ✅ `.github/workflows/ci.yml` - Added `UITests-DownloadFlow` matrix entry

**Test Files to Create:**
- `zpodUITests/OfflinePlaybackUITests.swift` (NEW)
- `zpodUITests/NetworkSimulationTests.swift` (NEW)
- `Packages/PlaybackEngine/Tests/BufferStrategyTests.swift` (NEW)

### ⏳ Phase 5: Siri Metadata Persistence (NOT STARTED) - **LOW PRIORITY**

**Estimated Effort:** 2-3 days

**Tasks:**
1. Create `EpisodeEntity` SwiftData model
2. Persist episodes on feed refresh
3. Load episodes from SwiftData on app launch
4. Update `SiriSnapshotCoordinator` to use persisted episodes
5. Add tests for metadata persistence
6. Verify Siri snapshots after restart

**Files to Create/Modify:**
- `Packages/Persistence/Sources/Persistence/Models/EpisodeEntity.swift` (NEW)
- `Packages/Persistence/Sources/Persistence/PersistenceCoordinator.swift`
- Siri snapshot integration in app initialization

## Timeline Estimate

| Phase | Priority | Effort | Status |
|-------|----------|--------|--------|
| Phase 1: UI Integration | HIGH | 2-3 days | ✅ DONE |
| Phase 2: Storage UI | MEDIUM | 1-2 days | ⏳ TODO |
| Phase 3: Network Handling | **HIGH** | 3-4 days | ⏳ **CRITICAL** |
| Phase 4: Test Coverage | MEDIUM | 3-4 days | ⏳ TODO |
| Phase 5: Siri Metadata | LOW | 2-3 days | ⏳ TODO |

**Total Estimated Effort:** 11-16 days (2-3 weeks)

**Recommended Approach:**
1. **Start with Phase 3** (Network Handling) - blocks production
2. **Then Phase 2** (Storage UI) - user-visible feature
3. **Then Phase 4** (Test Coverage) - validation
4. **Finally Phase 5** (Siri Metadata) - optional enhancement

## How to Test Current Implementation

### Manual Testing

1. **Download an episode:**
   ```
   - Launch app
   - Navigate to a podcast
   - Swipe left on an episode
   - Tap "Download"
   - Watch progress bar fill
   - Verify "Downloaded" badge appears
   ```

2. **Batch download:**
   ```
   - Tap "Select" in toolbar
   - Select multiple episodes
   - Tap "Download" in action bar
   - Verify all episodes show progress
   ```

3. **Offline playback:**
   ```
   - Download an episode
   - Enable airplane mode
   - Play the episode
   - Verify it plays without network
   ```

### Automated Testing

```bash
# Run all tests
./scripts/run-xcode-tests.sh

# Run just download infrastructure tests
./scripts/run-xcode-tests.sh -t NetworkingTests
./scripts/run-xcode-tests.sh -t PersistenceTests
./scripts/run-xcode-tests.sh -t LibraryFeatureTests

# Run UI tests (when created)
./scripts/run-xcode-tests.sh -t zpodUITests
```

## Known Issues

1. **Batch download was simulated** - Fixed in commit `95520d6`
2. **No network interruption handling** - Phase 3 (critical)
3. **No storage management UI** - Phase 2
4. **Episodes not persisted** - Phase 5 (low priority)
5. **Missing UI tests** - Phase 4

## Architecture Diagrams

### Download Flow

```
User Action (Swipe)
  ↓
EpisodeListViewModel.performSwipeAction(.download)
  ↓
EpisodeListViewModel.startEpisodeDownload(episode)
  ↓
DownloadCoordinatorBridge.enqueueEpisode(episode)
  ↓
DownloadCoordinator.addDownload(for: episode)
  ↓
FileManagerService.downloadEpisode(episode)
  ↓
URLSessionDownloadTask → Real network download
  ↓
Progress updates via Combine publisher
  ↓
EpisodeDownloadProgressCoordinator
  ↓
EpisodeRowView updates (progress bar, badge)
```

### Playback File Selection

```
EnhancedEpisodePlayer.play(episode)
  ↓
Check localFileProvider?(episode.id)
  ↓
  ├─ Local file exists?
  │   ↓
  │   Play from file:// URL (instant)
  │
  └─ No local file?
      ↓
      Play from episode.audioURL (stream)
```

## Documentation

- **Dev Log:** `dev-log/28.1.1-download-manager.md` (472 lines)
- **Issue:** `Issues/28.1-offline-streaming-playback-infrastructure.md`
- **Spec:** `spec/offline-playback.md`, `spec/streaming-playback.md`
- **Tests:** `Packages/Networking/Tests/NetworkingTests/DownloadCoordinatorTests.swift`
- **Implementation Plan:** Provided at start of this session

## Recent Commits

```
95520d6 [#28.1] Fix batch download operation to use real download manager
ffe276c [#28.1.1] Gate live feed test behind env flag
e3a97c3 [#28.1.1] Remove obsolete disabled FileManagerService test
917e180 [#28.1.1] Stop retrying cancelled downloads
89b1c8c [#28.1.1] Fix sendable warnings in networking tests
```

## Questions?

See:
- Implementation plan at start of this Claude session
- `dev-log/28.1.1-download-manager.md` for full timeline
- `Issues/28.1-offline-streaming-playback-infrastructure.md` for requirements
- `spec/offline-playback.md` and `spec/streaming-playback.md` for scenarios

# Session Notes: Player & Playlist UI Investigation
**Date**: 2025-12-22
**Session Goal**: Investigate and plan Player & Playlist UI wiring
**Status**: Investigation complete, implementation plan ready

---

## Session Summary

### What We Completed

1. ✅ **Confirmed SwiftLens work complete** (Issue 02.1.6.6)
   - All infrastructure in place
   - Integration tests passing
   - SwiftLens unit tests blocked by Issue 02.1.6.7 (Swift 6.2 compatibility)
   - Tracking issue created with TODO in code

2. ✅ **Identified Player & Playlist issues**:
   - **Player**: Issue 03.1.1 - Core Player Interface (4 sub-issues)
   - **Playlist**: Issue 06.1.1 - Core Playlist Creation and Management

3. ✅ **Investigated current implementation state**:
   - PlayerFeature package: Real UI exists but NOT wired to main app
   - PlaylistFeature package: Basic UI exists but showing empty data
   - Playback service: Exists in CarPlay dependencies, ready to use
   - Mini-player ViewModel: Already initialized but not displayed

4. ✅ **Created comprehensive implementation plan** (see below)

---

## Key Findings

### "Dummy Screens" Explained

The PlayerFeature and PlaylistFeature packages contain **production-ready UI code**, not empty placeholders:

- **PlayerFeature/MiniPlayerView.swift**: Sophisticated mini-player with animations, artwork, transport controls
- **PlayerFeature/ExpandedPlayerView.swift**: Full player interface with progress slider, controls
- **PlaylistFeature/PlaylistViews.swift**: Playlist list, detail views, empty states

**They're "dummy" only in the sense that:**
- Not wired into main app's TabView navigation
- Not connected to real data sources
- Player UI not connected to actual playback service

### Current App Structure (ContentView.swift)

```swift
TabView {
  LibraryView()           // ✅ Working
  DiscoverView()          // ⚠️ Placeholder
  PlaylistTabView()       // ⚠️ Shows empty data: playlists: []
  PlayerTabView()         // ⚠️ Dummy UI, not real ExpandedPlayerView
  SettingsView()          // ✅ Working
}

// Mini-player already initialized but never displayed:
@StateObject private var miniPlayerViewModel: MiniPlayerViewModel  // Line 333
```

### Architecture Ready Points

✅ **Playback service exists**:
```swift
let playbackDependencies: CarPlayDependencies  // Line 314
playbackDependencies.playbackService
playbackDependencies.queueManager
```

✅ **Models exist**:
- `Packages/CoreModels/Sources/CoreModels/Playlist.swift`
- `Packages/CoreModels/Sources/CoreModels/InMemoryPlaylistManager.swift`

---

## Implementation Plan Overview

### Phase 1: Player UI Wiring (Issue 03.1.1) - 2 Weeks

**Week 1:**
- **Task 1.1** (Days 1-2): Wire up mini-player
  - Add `MiniPlayerView` to ZStack with `.safeAreaInset(edge: .bottom)`
  - Add `.sheet()` for full player expansion
  - **Easiest win!** Code is 90% ready

- **Task 1.2** (Days 3-4): Replace dummy Player tab
  - Replace `PlayerTabView()` with `ExpandedPlayerView()`
  - Connect to existing ExpandedPlayerViewModel

- **Task 1.3** (Day 5 - Week 2 Day 1): Connect playback service
  - Wire play/pause/skip buttons to `playbackService` methods
  - Add state observation for progress updates
  - Implement scrubbing on progress slider

**Week 2:**
- **Task 1.4** (Days 2-3): System integration
  - Lock screen controls (MPNowPlayingInfoCenter)
  - Control Center integration
  - AirPlay support

### Phase 2: Playlist UI Wiring (Issue 06.1.1) - 2 Weeks

**Week 1:**
- **Task 2.1** (Days 1-3): Create playlist data source
  - Initialize `InMemoryPlaylistManager()`
  - Wire `PlaylistFeatureView` to show real playlists
  - Connect `episodesProvider` to podcastManager

- **Task 2.2** (Days 4-5 - Week 2 Day 1): Implement playlist creation
  - Add "+" button to toolbar
  - Create playlist creation sheet
  - Wire to playlistManager.add()

**Week 2:**
- **Task 2.3** (Days 2-4): Implement "Add to Playlist"
  - Add context menu to episode rows
  - Create playlist picker sheet
  - Wire to playlistManager.addEpisode()

- **Task 2.4** (Days 4-5): Playlist playback integration
  - "Play All" button queues episodes
  - Wire to queueManager
  - Test playlist playback flow

---

## Recommended Starting Point

**Start with Task 1.1: Wire Mini-Player** because:

1. **Immediate visible progress** (working mini-player in ~2 days)
2. **Code is 90% ready** - just needs to be added to view hierarchy
3. **Low risk** - isolated change, easy to test
4. **Unlocks full player** - leads naturally to Task 1.2

### Exact Changes for Task 1.1

**File**: `Packages/LibraryFeature/Sources/LibraryFeature/ContentView.swift`

**Line 343**, replace:
```swift
public var body: some View {
  ZStack(alignment: .bottom) {
    TabView {
      // ... existing tabs ...
    }
```

**With**:
```swift
public var body: some View {
  ZStack(alignment: .bottom) {
    TabView {
      // ... existing tabs ...
    }
    .safeAreaInset(edge: .bottom) {  // ← ADD THIS
      #if canImport(PlayerFeature)
        MiniPlayerView(
          viewModel: miniPlayerViewModel,
          onTapExpand: { showFullPlayer = true }
        )
      #endif
    }

    // Full player sheet
    #if canImport(PlayerFeature)
      .sheet(isPresented: $showFullPlayer) {  // ← ADD THIS
        ExpandedPlayerView(
          viewModel: ExpandedPlayerViewModel(
            playbackService: playbackDependencies.playbackService
          )
        )
      }
    #endif
  }
}
```

**Test**:
1. Run app
2. Play an episode from Library
3. Mini-player should appear at bottom
4. Tap mini-player → full player sheet opens

---

## Specifications Referenced

- **playback.md**: Core playback scenarios (speed, skip, timers, chapters)
- **ui.md**: Player interface design patterns
- **Issue 03.1.1**: Core Player Interface acceptance criteria
- **Issue 06.1.1**: Core Playlist Management acceptance criteria

---

## Outstanding Questions

None - investigation complete, ready to implement.

---

## 2025-12-23 CI Follow-Up

- Investigated CI failures in `ContentDiscoveryUITests` (search field input) and `PlayerNavigationTests` (background assertion timeouts).
- Updated search field discovery to prefer `searchFields`, added keyboard focus checks, and predicate-based wait for input echo.
- Added Springboard readiness check before UI test app launches to reduce background assertion launch flakiness.

---

## Current Branch Status

**Branch**: `docs/swiftlens-infrastructure-setup`
**Commits ahead**: 1 (tracking issue for SwiftLens Swift 6.2 compatibility)
**Status**: Ready to push, but can wait until after Player work

**Stale todos** (from SwiftLens work - should be cleared):
1. Run targeted SwiftLens tests to verify changes
2. Run full regression test before push
3. Push SwiftLens integration to GitHub

**New todos should be**:
1. Implement Task 1.1: Wire mini-player
2. Test mini-player integration
3. Implement Task 1.2: Replace Player tab

---

## Next Session Action Items

When resuming:
1. Clear stale SwiftLens todos
2. Create fresh todos for Player implementation
3. Start with Task 1.1 (mini-player wiring)
4. Consider creating sub-issues for tracking (03.1.1.1, 03.1.1.2, etc.)

---

## Update (Resumed Session - Later 2025-12-22)

### CRITICAL DISCOVERY: Mini-Player Already Integrated!

The investigation revealed that **Task 1.1 was already completed** in a previous commit:

**Evidence**:
- **ContentView.swift:389-408**: Mini-player fully integrated with MiniPlayerView and ExpandedPlayerView sheet
- **Commit**: `20a9605 Issue 03.1.1.1: mini-player UI integration`
- **GitHub Issue #108**: Was CLOSED (but reopened for investigation)

### Playback Trigger Confirmed

**Quick Play Button Location**: `EpisodeRowView.swift:1041-1049`
```swift
Button(action: onQuickPlay) {
  Image(systemName: episode.isInProgress ? "play.fill" : "play.circle")
    .foregroundStyle(.primary)
    .font(.title3)
}
.accessibilityLabel("Quick play")
```

**Playback Flow**:
1. User taps play icon in episode row (right side of row)
2. `onQuickPlay` callback triggered (EpisodeListView.swift:501-505)
3. Calls `viewModel.quickPlayEpisode(episode)`
4. Delegates to `EpisodePlaybackCoordinator.quickPlayEpisode`
5. Calls `playbackService.play(episode:duration:)` (EpisodePlaybackCoordinator.swift:68)
6. Should trigger `MiniPlayerViewModel` to show mini-player

### Next Investigation Steps

1. ✅ Verified mini-player integration code exists
2. ✅ Documented playback flow from episode row to playback service
3. 🔄 **NEXT**: Test actual app to confirm mini-player appears when playing episode
4. ⏳ Verify MiniPlayerViewModel visibility logic
5. ⏳ Document whether Issue #108 should be closed or if there are missing pieces

### Possible Outcomes

**Scenario A**: Mini-player works perfectly
- Close Issue #108 as already complete
- Update session notes: no Player work needed!
- Move to Playlist UI wiring (Task 2.1)

**Scenario B**: Mini-player doesn't appear
- Debug visibility conditions in MiniPlayerViewModel
- Check if `queueIsEmpty` closure is blocking visibility
- Fix integration issues

**Scenario C**: Playback service doesn't actually play audio
- Investigate PlaybackService implementation
- May need to wire audio session setup
- Follow Task 1.3 and 1.4 from original plan

---

**Session saved**: 2025-12-22
**Resume point**: Test mini-player by running app and tapping Quick Play button in Library episode row

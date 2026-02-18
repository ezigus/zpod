I'm running in a restricted permission mode that prevents writing files and running build tools. This is a planning-only pipeline stage, so I need to present the plan directly in the conversation since I can't write to the plan file.

`★ Insight ─────────────────────────────────────`
**Why the pipeline stalled for 27 iterations**: The previous autonomous loop was blocked because `InMemoryPlaylistManager` in CoreModels uses `@MainActor` but conforms to `PlaylistManaging: Sendable`. Under Swift 6 strict concurrency, this is a conformance error — the loop tried to fix it repeatedly but was denied file write permissions. This is the critical first fix in the plan.
`─────────────────────────────────────────────────`

---

# Implementation Plan: 06.1.1 Core Playlist Creation and Management

## Current State Assessment

The codebase already has substantial playlist infrastructure:

| Layer | Status | Key Files |
|-------|--------|-----------|
| **Models** | `Playlist`, `SmartPlaylist`, `PlaylistChange` | `CoreModels/Playlist.swift` |
| **Protocol** | `PlaylistManaging` with full CRUD | `CoreModels/PlaylistManaging.swift` |
| **Persistence** | `SwiftDataPlaylistRepository` (manual CRUD done) | `Persistence/SwiftDataPlaylistRepository.swift` |
| **UI** | Read-only list + detail views | `PlaylistFeature/PlaylistViews.swift` |
| **Integration** | `ContentView` wires `PlaylistTabView` | `LibraryFeature/ContentView.swift` |
| **Tests** | Integration tests for playlist+playback | `IntegrationTests/PlaylistPlaybackIntegrationTests.swift` |

**What's missing** (this plan delivers):
1. **Critical bug fix**: Swift 6 conformance error on `InMemoryPlaylistManager`
2. Playlist creation/editing UI (name + description)
3. Drag-and-drop episode reordering in detail view
4. "Add to Playlist" sheet from episode contexts
5. Playlist deletion and duplication in UI
6. ViewModel layer bridging UI ↔ PlaylistManaging
7. Description field on the Playlist model

---

## Files to Modify

### CoreModels Package (Model Layer)
1. **`Packages/CoreModels/Sources/CoreModels/Playlist.swift`** — Add optional `description` field; add `withDescription(_:)` builder
2. **`Packages/CoreModels/Sources/CoreModels/InMemoryPlaylistManager.swift`** — Fix Swift 6: remove `@MainActor`, use `final class: @unchecked Sendable`, consolidate dual `#if canImport(Combine)` implementations

### Persistence Package
3. **`Packages/Persistence/Sources/Persistence/PlaylistEntity.swift`** — Add `playlistDescription` property; update `toDomain()`/`fromDomain()`/`updateFrom()`

### PlaylistFeature Package (UI Layer)
4. **`Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistViewModel.swift`** — **NEW**: `@MainActor @Observable` view model with CRUD + reorder + duplicate
5. **`Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistViews.swift`** — Upgrade to interactive: create button, swipe-delete, context menus, drag-and-drop
6. **`Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistCreationView.swift`** — **NEW**: Sheet for create/edit playlist
7. **`Packages/PlaylistFeature/Sources/PlaylistFeature/AddToPlaylistView.swift`** — **NEW**: Sheet for adding episodes to playlists

### LibraryFeature Package (Integration)
8. **`Packages/LibraryFeature/Sources/LibraryFeature/ContentView.swift`** — Update `PlaylistTabView` to use `PlaylistViewModel`

### Tests
9. **`Packages/PlaylistFeature/Tests/PlaylistFeatureTests/PlaylistViewModelTests.swift`** — **NEW**: ViewModel unit tests
10. **`Packages/CoreModels/Tests/CoreModelsTests/PlaylistModelTests.swift`** — **NEW**: Model builder method tests
11. **`Packages/PlaylistFeature/Tests/PlaylistFeatureTests/PlaylistFeatureTests.swift`** — Replace stub

---

## Implementation Steps

### Step 1: Fix InMemoryPlaylistManager Swift 6 Conformance
Remove `@MainActor` from both `#if canImport(Combine)` branches. Consolidate to a single `final class InMemoryPlaylistManager: PlaylistManaging, @unchecked Sendable` implementation (no Combine dependency needed for in-memory test double). This mirrors `InMemoryPodcastManager` in TestSupport.

### Step 2: Add Description Field to Playlist Model
Add `public let description: String` (default `""`) to `Playlist`. Add `withDescription(_:)` builder. Update `PlaylistEntity` with `playlistDescription` property (avoids `CustomStringConvertible` conflict) and all conversion methods.

### Step 3: Create PlaylistViewModel
`@MainActor @Observable` class holding `any PlaylistManaging`. Exposes `playlists: [Playlist]`, provides: `createPlaylist(name:description:)`, `deletePlaylist(id:)`, `duplicatePlaylist(id:)`, `renamePlaylist(id:name:)`, `addEpisodes(_:to:)`, `removeEpisode(_:from:)`, `reorderEpisodes(in:from:to:)`. Calls `refreshPlaylists()` after each mutation.

### Step 4: Create PlaylistCreationView
SwiftUI sheet with name text field (required), optional description, Save/Cancel. Supports create and edit modes via optional `existingPlaylist` parameter.

### Step 5: Create AddToPlaylistView
Accepts `episodeIds: [String]`, lists existing playlists with tap-to-add, "New Playlist" row at top, checkmarks for playlists already containing the episodes.

### Step 6: Upgrade PlaylistFeatureView
- Toolbar "+" button → presents `PlaylistCreationView`
- `.onDelete` swipe on playlist rows
- Context menu: Edit, Duplicate, Delete

### Step 7: Upgrade PlaylistDetailView
- `.onMove` for drag-and-drop reordering
- Swipe-to-remove on episode rows
- EditButton in toolbar for reorder mode

### Step 8: Wire ContentView Integration
Update `PlaylistTabView` to create `PlaylistViewModel` from `playlistManager` and pass to `PlaylistFeatureView`.

### Step 9: Write Unit Tests
`PlaylistViewModelTests` and `PlaylistModelTests` covering all CRUD + reorder + duplicate operations.

### Step 10-13: Syntax check → Targeted tests → Full regression

---

## Task Checklist

- [ ] Task 1: Fix `InMemoryPlaylistManager` Swift 6 conformance (remove `@MainActor`, `@unchecked Sendable`)
- [ ] Task 2: Add `description` field to `Playlist` model + `PlaylistEntity` conversion
- [ ] Task 3: Create `PlaylistViewModel` with CRUD/reorder/duplicate methods
- [ ] Task 4: Create `PlaylistCreationView` (create + edit sheet)
- [ ] Task 5: Create `AddToPlaylistView` (episode addition sheet)
- [ ] Task 6: Upgrade `PlaylistFeatureView` with toolbar create, swipe-delete, context menus
- [ ] Task 7: Upgrade `PlaylistDetailView` with drag-and-drop reorder + swipe-remove
- [ ] Task 8: Update `ContentView` `PlaylistTabView` integration
- [ ] Task 9: Write `PlaylistViewModelTests` + `PlaylistModelTests`
- [ ] Task 10: Run syntax check and fix Swift 6 issues
- [ ] Task 11: Run targeted package tests
- [ ] Task 12: Run full regression suite
- [ ] Task 13: Create dev-log entry

---

## Testing Approach

### Unit Tests
- **PlaylistViewModelTests**: Create → verify in list; Rename → verify; Delete → verify removed; Duplicate → verify copy with new ID; Add episode → verify; Remove episode → verify; Reorder → verify order
- **PlaylistModelTests**: `withDescription`, `withName`, `withEpisodes` preserve fields and bump `updatedAt`

### Existing Integration Tests
- `PlaylistPlaybackIntegrationTests` must continue passing (validates playlist→playback queue flow)

### Build Gates
- Syntax: `./scripts/run-xcode-tests.sh -s`
- Full regression: `./scripts/run-xcode-tests.sh`

---

## Definition of Done

- [ ] `InMemoryPlaylistManager` compiles without Swift 6 concurrency errors
- [ ] `Playlist` model includes description field
- [ ] Users can create playlists from the Playlists tab via "+" toolbar button
- [ ] Users can edit playlist name/description from detail view
- [ ] Users can delete playlists via swipe or context menu
- [ ] Users can duplicate playlists via context menu
- [ ] Users can reorder episodes via drag-and-drop (Edit mode)
- [ ] Users can remove episodes from a playlist via swipe
- [ ] `AddToPlaylistView` ready for integration from episode contexts
- [ ] All new views have accessibility identifiers
- [ ] Unit tests pass for ViewModel CRUD, reorder, duplicate
- [ ] Syntax check passes
- [ ] Full regression passes
- [ ] No force unwraps in production code

---

## Architecture Notes

`★ Insight ─────────────────────────────────────`
- **Why `@Observable` over `ObservableObject`**: Project targets iOS 18+. The Observation framework provides finer-grained view invalidation and eliminates the need for `@StateObject`/`@ObservedObject` wrappers — views only re-render when the specific properties they read change.
- **Why ViewModel refreshes after mutations**: `PlaylistManaging` is synchronous without change streams. The ViewModel calls `refreshPlaylists()` after each write operation. A future enhancement could add `AsyncStream<PlaylistChange>` for reactive updates.
- **Deferred features**: Smart suggestions, shuffle modes, cross-device sync, folders, analytics — all mentioned in the issue but scoped out to future work.
`─────────────────────────────────────────────────`

---

**Note**: I was unable to write this plan to `.claude/pipeline-artifacts/plan.md` because file write permissions are denied in the current mode. To proceed with the pipeline, this plan needs to be written to that file and approved.

`★ Insight ─────────────────────────────────────`
**Key architectural finding**: The zpod playlist infrastructure is a classic "backend done, frontend not wired" scenario. `InMemoryPlaylistManager` in CoreModels has full CRUD with Combine change notifications, but `ContentView.swift:159` hardcodes `PlaylistFeatureView(playlists: [], episodesProvider: { _ in [] })`. The plan below bridges this gap across 5 layers: protocol extraction → SwiftData persistence → ViewModels → UI views → app wiring.

**Why SwiftData over UserDefaults**: Playlists have ordered episode arrays and will grow. SwiftData gives us indexed queries, lightweight migration, and consistency with the existing `PodcastEntity`/`EpisodeEntity` pattern. UserDefaults would require manual JSON encoding and doesn't scale for relational queries.
`─────────────────────────────────────────────────`

---

# Implementation Plan: 06.1.1 Core Playlist Creation and Management

## Overview

Issue 06.1.1 delivers the core playlist user experience: creating, editing, reordering, and playing playlists. The **backend models already exist** (`Playlist`, `SmartPlaylist`, `InMemoryPlaylistManager` in CoreModels). The work is:

1. **Persist** playlists via a new SwiftData entity + repository
2. **Wire** the PlaylistFeatureView to live data (currently empty arrays)
3. **Build** creation, editing, episode-addition, and reordering UI
4. **Integrate** playlist playback with the existing player infrastructure

---

## Files to Modify

### New Files to Create

| # | File | Purpose |
|---|------|---------|
| 1 | `Packages/CoreModels/Sources/CoreModels/PlaylistManaging.swift` | `PlaylistManaging` protocol extracted from `InMemoryPlaylistManager` |
| 2 | `Packages/Persistence/Sources/Persistence/PlaylistEntity.swift` | SwiftData `@Model` for playlists with `toDomain()`/`fromDomain()` |
| 3 | `Packages/Persistence/Sources/Persistence/PlaylistRepository.swift` | `SwiftDataPlaylistRepository` — serial-queue CRUD |
| 4 | `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistViewModel.swift` | `@MainActor ObservableObject` VM for playlist list |
| 5 | `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistCreationView.swift` | Sheet for new playlist (name field) |
| 6 | `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistEditView.swift` | Edit playlist name + settings |
| 7 | `Packages/PlaylistFeature/Sources/PlaylistFeature/AddToPlaylistView.swift` | Sheet for adding episodes to playlists |
| 8 | `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistDetailViewModel.swift` | VM for detail — reorder, remove, playback |
| 9 | `Packages/Persistence/Tests/PersistenceTests/PlaylistRepositoryTests.swift` | Unit tests for persistence CRUD |
| 10 | `Packages/PlaylistFeature/Tests/PlaylistFeatureTests/PlaylistViewModelTests.swift` | Unit tests for VM logic |
| 11 | `zpodUITests/PlaylistCreationUITests.swift` | UI tests for playlist flows |
| 12 | `dev-log/06.1.1-core-playlist-creation-management.md` | Dev log |

### Existing Files to Modify

| # | File | Change |
|---|------|--------|
| 13 | `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistViews.swift` | Accept `PlaylistViewModel` instead of raw arrays; add toolbar "+", swipe-to-delete, drag-and-drop reorder |
| 14 | `Packages/PlaylistFeature/Package.swift` | Add `Persistence` dependency |
| 15 | `Packages/LibraryFeature/Sources/LibraryFeature/ContentView.swift` | Wire `PlaylistTabView` to real `PlaylistViewModel` (replace line 159 empty arrays) |
| 16 | `Packages/LibraryFeature/Sources/LibraryFeature/EpisodeListView.swift` | Add "Add to Playlist" context menu on episode rows |
| 17 | `Packages/CoreModels/Sources/CoreModels/Playlist.swift` | Add optional `description` field to `Playlist` struct |
| 18 | `Packages/CoreModels/Sources/CoreModels/InMemoryPlaylistManager.swift` | Conform to new `PlaylistManaging` protocol |
| 19 | `zpod/ZpodApp.swift` | Register `PlaylistEntity` in ModelContainer schema |

---

## Implementation Steps

### Phase 1: Persistence Foundation (Steps 1–4)

**Step 1**: Extract `PlaylistManaging` protocol from `InMemoryPlaylistManager`
- Define protocol in `CoreModels/PlaylistManaging.swift`
- Methods: `createPlaylist`, `updatePlaylist`, `deletePlaylist`, `findPlaylist`, `addEpisode`, `removeEpisode`, `reorderEpisodes`
- `@Published var playlists: [Playlist]` as protocol requirement
- Make `InMemoryPlaylistManager` conform

**Step 2**: Create `PlaylistEntity` SwiftData model
- `@Model` with `@Attribute(.unique) var id: String`
- Fields: `name`, `playlistDescription`, `episodeIds: [String]`, `continuousPlayback`, `shuffleAllowed`, `createdAt`, `updatedAt`
- `toDomain()` → `Playlist`, `fromDomain()`, `updateFrom()` — matches `PodcastEntity` pattern

**Step 3**: Create `SwiftDataPlaylistRepository`
- Serial queue for thread safety (mirrors `SwiftDataPodcastRepository`)
- Methods: `all()`, `find(id:)`, `save(_:)`, `delete(id:)`
- Entity ↔ domain conversion inside the serial queue

**Step 4**: Register `PlaylistEntity` in `ZpodApp.swift` ModelContainer schema

### Phase 2: ViewModel Layer (Steps 5–6)

**Step 5**: Build `PlaylistViewModel`
- `@Published playlists: [Playlist]`, `showingCreationSheet: Bool`
- Init takes repository + `PodcastManaging` for episode resolution
- `loadPlaylists()`, `createPlaylist(name:)`, `deletePlaylist(id:)`
- `episodesFor(playlist:)` resolves `episodeIds` → `[Episode]` via podcast manager

**Step 6**: Build `PlaylistDetailViewModel`
- Owns single `Playlist` + resolved `[Episode]`
- `reorderEpisodes(from:to:)` — uses `.onMove` IndexSet signature
- `removeEpisode(at:)`, `playAll()`, `shufflePlay()`

### Phase 3: UI Views (Steps 7–11)

**Step 7**: `PlaylistCreationView` — sheet with name TextField + Create button

**Step 8**: `PlaylistEditView` — rename + toggle settings

**Step 9**: Refactor `PlaylistViews.swift` — accept VM, toolbar "+", swipe-delete, drag-and-drop episode reorder in detail

**Step 10**: `AddToPlaylistView` — sheet listing playlists for quick episode addition

**Step 11**: Wire `ContentView.PlaylistTabView` to `PlaylistViewModel` with real repository

### Phase 4: Episode Addition + Playback (Steps 12–13)

**Step 12**: Add "Add to Playlist" context menu on `EpisodeListView` episode rows

**Step 13**: Connect `playAll()`/`shufflePlay()` to existing `queueManager` in player infrastructure

### Phase 5: Testing (Steps 14–15)

**Step 14**: Persistence tests — in-memory `ModelContainer`, CRUD + reorder + duplicate prevention

**Step 15**: ViewModel tests — inject `InMemoryPlaylistManager`, verify state transitions

---

## Task Checklist

- [ ] Task 1: Extract `PlaylistManaging` protocol from `InMemoryPlaylistManager`
- [ ] Task 2: Create `PlaylistEntity` SwiftData model with domain conversions
- [ ] Task 3: Create `SwiftDataPlaylistRepository` with serial-queue CRUD
- [ ] Task 4: Register `PlaylistEntity` in `ZpodApp.swift` ModelContainer schema
- [ ] Task 5: Build `PlaylistViewModel` with CRUD + episode resolution
- [ ] Task 6: Build `PlaylistDetailViewModel` with reorder/remove/playback
- [ ] Task 7: Build `PlaylistCreationView` sheet
- [ ] Task 8: Build `PlaylistEditView` sheet
- [ ] Task 9: Refactor `PlaylistViews.swift` to accept VM + add interactions
- [ ] Task 10: Build `AddToPlaylistView` for episode addition
- [ ] Task 11: Wire `ContentView.PlaylistTabView` to real `PlaylistViewModel`
- [ ] Task 12: Add "Add to Playlist" context menu on episode rows
- [ ] Task 13: Connect playlist playback to existing queue manager
- [ ] Task 14: Write persistence unit tests
- [ ] Task 15: Write ViewModel unit tests

---

## Testing Approach

| Layer | Command | What's Verified |
|-------|---------|-----------------|
| Syntax gate | `./scripts/run-xcode-tests.sh -s` | Swift 6 compilation, concurrency |
| Persistence | `./scripts/run-xcode-tests.sh -t PersistenceTests` | CRUD, reorder, duplicates |
| ViewModel | `./scripts/run-xcode-tests.sh -t PlaylistFeatureTests` | State transitions, episode resolution |
| Existing models | `./scripts/run-xcode-tests.sh -t CoreModelsTests` | Protocol extraction didn't break anything |
| Build | `./scripts/run-xcode-tests.sh -b zpod` | Full workspace compiles |
| Full regression | `./scripts/run-xcode-tests.sh` | Everything passes before push |

---

## Definition of Done

- [ ] Playlist creation/editing completes within 500ms
- [ ] Drag-and-drop reordering works smoothly with 20+ episodes
- [ ] Episode addition succeeds from episode list context menu
- [ ] Playlist playback integrates with existing player (Play All, Shuffle)
- [ ] Playlists persist across app restarts (SwiftData)
- [ ] All code passes Swift 6 strict concurrency (`-s` syntax gate)
- [ ] Full regression suite passes
- [ ] Accessibility identifiers on all interactive elements
- [ ] Dev log updated
- [ ] Code committed, PR created

---

## Dependency Graph

```
CoreModels (PlaylistManaging protocol + Playlist model)
    ↓
Persistence (PlaylistEntity + SwiftDataPlaylistRepository)
    ↓
PlaylistFeature (ViewModels + Views)
    ↓
LibraryFeature/ContentView (wires PlaylistFeature to app)
    ↓
zpod/ZpodApp (registers PlaylistEntity in ModelContainer)
```

## Risk Mitigation

1. **SwiftData schema migration**: Adding `PlaylistEntity` is an additive change — SwiftData handles this automatically, no manual migration needed.
2. **Swift 6 concurrency**: Access `PlaylistEntity` only through serial-queue repository (matches existing pattern). ViewModels are `@MainActor`.
3. **Episode resolution performance**: Walking all podcasts for episode lookup is O(total_episodes). Acceptable at current scale (<1000). Future optimization: add episode-ID index.
4. **No package dependency cycles**: `PlaylistFeature` → `Persistence` → `CoreModels` is a clean DAG.

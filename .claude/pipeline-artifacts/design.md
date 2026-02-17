

Excellent — now I have a thorough understanding of the codebase. Let me synthesize everything into the ADR.

`★ Insight ─────────────────────────────────────`
**Three critical findings that refine the plan:**

1. **No `PlaylistManaging` protocol exists** — `InMemoryPlaylistManager` is a concrete `@MainActor` class, not behind an abstraction. The plan correctly identifies this gap. Extracting a protocol is prerequisite work.

2. **Queue management lives in LibraryFeature**, not PlaybackEngine — `CarPlayPlaybackCoordinator` implements `CarPlayQueueManaging` with `playNow(_:)` and `enqueue(_:)`. Playlist playback must wire through this coordinator, not directly to the AVPlayer engine.

3. **The existing persistence pattern uses DispatchQueue.sync, not actors** — `SwiftDataPodcastRepository` uses `private let serialQueue: DispatchQueue` with synchronous dispatch for thread safety (not Swift actors). The playlist repository must follow this same pattern for consistency and to avoid mixing concurrency models within the Persistence package.
`─────────────────────────────────────────────────`

---

# Design: 06.1.1 Core Playlist Creation and Management

## Context

The zpod podcast app has a complete in-memory playlist backend (`InMemoryPlaylistManager` in CoreModels) with CRUD operations, episode reordering, duplicate prevention, and Combine change notifications. However, playlists are **not surfaced to users**:

- `ContentView.swift:157-161` hardcodes `PlaylistFeatureView(playlists: [], episodesProvider: { _ in [] })` — the Playlists tab always shows "No playlists yet"
- No persistence layer exists — playlists live only in RAM via `InMemoryPlaylistManager` and are lost on app restart
- No creation, editing, or "Add to Playlist" UI exists
- No protocol abstracts playlist management — `InMemoryPlaylistManager` is a concrete `@MainActor` class, making it untestable in isolation and impossible to swap for a persistent implementation

**Constraints:**
- Swift 6.1.2 strict concurrency — all new code must pass `-s` syntax gate
- iOS 18+ only (no backwards compatibility burden)
- Existing persistence uses SwiftData with serial DispatchQueue pattern (`SwiftDataPodcastRepository`)
- Existing queue management lives in `CarPlayPlaybackCoordinator` (`CarPlayQueueManaging` protocol) in LibraryFeature
- The `Playlist` struct is an immutable value type with builder methods (`withName(_:)`, `withEpisodes(_:)`) — modifications return new instances with bumped `updatedAt`
- CI tests must be self-supporting (no persisted state between test runs)

## Decision

### 1. Protocol Extraction: `PlaylistManaging`

Extract a `PlaylistManaging` protocol from `InMemoryPlaylistManager`'s public API in CoreModels. This enables:
- Swapping `InMemoryPlaylistManager` (tests) for `SwiftDataPlaylistRepository` (production)
- Dependency injection at the `ContentView` level
- Clean testability without hitting SwiftData

The protocol will be `@MainActor`-isolated to match the existing manager and allow `@Published` properties in conforming types. It covers manual playlists only for 06.1.1 scope (smart playlists are a future issue).

```swift
@MainActor
public protocol PlaylistManaging: AnyObject, Observable {
    var playlists: [Playlist] { get }
    func createPlaylist(_ playlist: Playlist)
    func updatePlaylist(_ playlist: Playlist)
    func deletePlaylist(id: String)
    func findPlaylist(id: String) -> Playlist?
    func addEpisode(episodeId: String, to playlistId: String)
    func removeEpisode(episodeId: String, from playlistId: String)
    func reorderEpisodes(in playlistId: String, from source: IndexSet, to destination: Int)
}
```

### 2. SwiftData Persistence: `PlaylistEntity` + `SwiftDataPlaylistRepository`

**Entity design** follows the established `PodcastEntity`/`EpisodeEntity` pattern:
- `@Model final class PlaylistEntity` with `@Attribute(.unique) var id: String`
- All fields are primitives/arrays of primitives (no relationships — `episodeIds` stored as `[String]`)
- `toDomain() -> Playlist` and `static fromDomain(_ playlist: Playlist) -> PlaylistEntity` conversions
- `func updateFrom(_ playlist: Playlist)` for in-place updates

**Repository design** mirrors `SwiftDataPodcastRepository`:
- `final class SwiftDataPlaylistRepository: PlaylistManaging, @unchecked Sendable`
- Thread safety via `private let serialQueue: DispatchQueue` with `serialQueue.sync {}` (matches existing pattern — NOT actor-based)
- `ModelContainer` injected via init; private `ModelContext` created on the serial queue
- `@Published var playlists: [Playlist]` kept in sync after each mutation by re-querying
- `saveContext()` with rollback on failure

**Schema registration:** `PlaylistEntity.self` added to `ZpodApp.sharedModelContainer` schema array. SwiftData handles additive schema changes automatically — no migration needed.

### 3. ViewModel Layer

**`PlaylistViewModel`** (`@MainActor ObservableObject`):
- Owns a `PlaylistManaging` reference (injected)
- Owns a `PodcastManaging` reference for episode resolution (`episodeIds → [Episode]`)
- Exposes `playlists`, `showingCreationSheet`, `showingAddToPlaylistSheet`
- Methods: `createPlaylist(name:)`, `deletePlaylist(id:)`, `episodesFor(playlist:) -> [Episode]`

**`PlaylistDetailViewModel`** (`@MainActor ObservableObject`):
- Owns a single `Playlist` + resolved `[Episode]` array
- Methods: `reorderEpisodes(from:to:)`, `removeEpisode(at:)`, `playAll()`, `shufflePlay()`
- Playback integration: calls into `CarPlayQueueManaging` (enqueue resolved episodes)

### 4. UI Views

Refactor existing `PlaylistViews.swift` to accept `PlaylistViewModel` instead of raw arrays. Add:
- **Toolbar "+"** button → presents `PlaylistCreationView` sheet (name TextField + Create)
- **Swipe-to-delete** on playlist rows
- **Drag-and-drop reorder** (`.onMove`) on episodes in `PlaylistDetailView`
- **`PlaylistEditView`** — sheet for renaming + toggling settings
- **`AddToPlaylistView`** — sheet listing existing playlists for quick episode addition (presented from episode row context menu)

### 5. App Wiring

In `ContentView.swift`, replace the hardcoded empty `PlaylistTabView` with:
```swift
private struct PlaylistTabView: View {
    @StateObject private var viewModel: PlaylistViewModel
    
    init(playlistManager: PlaylistManaging, podcastManager: PodcastManaging) {
        _viewModel = StateObject(wrappedValue: PlaylistViewModel(
            playlistManager: playlistManager,
            podcastManager: podcastManager
        ))
    }
    
    var body: some View {
        PlaylistFeatureView(viewModel: viewModel)
    }
}
```

The `PlaylistManaging` instance is created in `ZpodApp.swift` alongside the existing `sharedPodcastRepository`, passed through `ContentView.init`.

### 6. Episode Addition Entry Point

Add a `.contextMenu` on episode rows in `EpisodeListView.swift` with an "Add to Playlist" action that presents `AddToPlaylistView` as a sheet. This is preferred over adding another swipe action because swipe slots are already occupied by existing actions (mark played, download, archive).

### 7. Data Flow

```
ZpodApp
  ├─ sharedModelContainer (PlaylistEntity registered)
  ├─ sharedPlaylistRepository: SwiftDataPlaylistRepository
  └─ ContentView(podcastManager:, playlistManager:)
       └─ PlaylistTabView
            └─ PlaylistViewModel(playlistManager:, podcastManager:)
                 └─ PlaylistFeatureView(viewModel:)
                      ├─ PlaylistCreationView (sheet)
                      ├─ PlaylistDetailView → PlaylistDetailViewModel
                      │    ├─ .onMove (reorder)
                      │    ├─ .onDelete (remove episode)
                      │    └─ Play All / Shuffle → CarPlayQueueManaging
                      └─ PlaylistEditView (sheet)

EpisodeListView
  └─ .contextMenu → AddToPlaylistView (sheet)
       └─ playlistManager.addEpisode(episodeId:to:)
```

## Alternatives Considered

### 1. UserDefaults-based persistence
- **Pros:** Simpler setup, no SwiftData schema registration, matches `UserDefaultsSettingsRepository` pattern
- **Cons:** No indexed queries, manual JSON encoding for `[String]` arrays, doesn't scale for relational queries (e.g., "find all playlists containing episode X"), inconsistent with the primary persistence layer (`PodcastEntity`/`EpisodeEntity` use SwiftData). Rejected because playlists have ordered episode arrays that will grow and benefit from proper database storage.

### 2. Skip protocol extraction, use `InMemoryPlaylistManager` directly with SwiftData behind it
- **Pros:** Fewer files, faster initial implementation
- **Cons:** `InMemoryPlaylistManager` is `@MainActor`-isolated and stores everything in `@Published` arrays — bolting SwiftData onto it would require either breaking actor isolation for disk I/O or making all persistence calls async. The serial-queue repository pattern already exists and is proven. Also prevents clean testing. Rejected because it fights the existing architecture.

### 3. Add `Persistence` as a dependency of `PlaylistFeature` directly (ViewModels call repository)
- **Pros:** ViewModels can call repository directly without going through a protocol
- **Cons:** Creates a hard dependency from feature UI → persistence implementation. Every other feature (Library, Discover) accesses persistence through protocols injected from the app target. Violates the existing dependency direction: `App → Feature → CoreModels`, with Persistence injected via protocols. Rejected for architectural consistency.

### 4. Actor-based repository instead of serial DispatchQueue
- **Pros:** More "modern Swift" concurrency, compiler-enforced isolation
- **Cons:** Every existing SwiftData repository uses serial DispatchQueue (`SwiftDataPodcastRepository`, `SwiftDataEpisodeSnapshotRepository`). Mixing concurrency models within the Persistence package creates confusion and potential deadlock risks at boundaries. `ModelContext` is not `Sendable` and must stay on a single thread — DispatchQueue achieves this with less overhead than actor isolation. Rejected for consistency with established patterns.

## Implementation Plan

### Files to Create

| # | Path | Purpose |
|---|------|---------|
| 1 | `Packages/CoreModels/Sources/CoreModels/PlaylistManaging.swift` | Protocol extracted from `InMemoryPlaylistManager` |
| 2 | `Packages/Persistence/Sources/Persistence/PlaylistEntity.swift` | SwiftData `@Model` with `toDomain()`/`fromDomain()` |
| 3 | `Packages/Persistence/Sources/Persistence/SwiftDataPlaylistRepository.swift` | Serial-queue CRUD conforming to `PlaylistManaging` |
| 4 | `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistViewModel.swift` | `@MainActor ObservableObject` for playlist list |
| 5 | `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistDetailViewModel.swift` | VM for detail: reorder, remove, playback |
| 6 | `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistCreationView.swift` | Sheet: name field + Create button |
| 7 | `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistEditView.swift` | Sheet: rename + settings toggles |
| 8 | `Packages/PlaylistFeature/Sources/PlaylistFeature/AddToPlaylistView.swift` | Sheet: select playlist for episode addition |
| 9 | `Packages/Persistence/Tests/PersistenceTests/PlaylistRepositoryTests.swift` | CRUD, reorder, duplicate prevention tests |
| 10 | `Packages/PlaylistFeature/Tests/PlaylistFeatureTests/PlaylistViewModelTests.swift` | State transition + episode resolution tests |
| 11 | `zpodUITests/PlaylistCreationUITests.swift` | End-to-end creation/edit/delete UI tests |
| 12 | `dev-log/06.1.1-core-playlist-creation-management.md` | Dev log |

### Files to Modify

| # | Path | Change |
|---|------|--------|
| 13 | `Packages/CoreModels/Sources/CoreModels/InMemoryPlaylistManager.swift` | Conform to new `PlaylistManaging` protocol |
| 14 | `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistViews.swift` | Accept `PlaylistViewModel`; add toolbar "+", swipe-delete, `.onMove` reorder |
| 15 | `Packages/PlaylistFeature/Package.swift` | Add `Persistence` dependency |
| 16 | `Packages/LibraryFeature/Sources/LibraryFeature/ContentView.swift` | Wire `PlaylistTabView` to real `PlaylistViewModel` via injected `PlaylistManaging` |
| 17 | `Packages/LibraryFeature/Sources/LibraryFeature/EpisodeListView.swift` | Add `.contextMenu` with "Add to Playlist" on episode rows |
| 18 | `zpod/ZpodApp.swift` | Register `PlaylistEntity` in ModelContainer schema; create `sharedPlaylistRepository`; pass to ContentView |

### Dependencies
- **New package dependency:** `PlaylistFeature` → `Persistence` (same as `LibraryFeature` → `Persistence`)
- **No external dependencies added.** All work uses existing SwiftData, Combine, and SwiftUI.

### Risk Areas

1. **ModelContainer schema addition** — Adding `PlaylistEntity.self` to the schema array is additive; SwiftData handles this without migration. Risk is low but should be verified by building against a device with existing data.

2. **Episode resolution performance** — `episodesFor(playlist:)` must resolve `[String]` episode IDs to `[Episode]` objects by walking `PodcastManaging.all()`. This is O(total_episodes) per call. At current scale (<1,000 episodes), this is sub-millisecond. If scale grows, add an episode-ID lookup index. **Mitigation:** cache the resolution result in `PlaylistDetailViewModel`; re-resolve only on playlist change.

3. **Swift 6 concurrency at the seam** — `SwiftDataPlaylistRepository` uses a serial DispatchQueue but conforms to `@MainActor PlaylistManaging`. The `@unchecked Sendable` annotation (matching `SwiftDataPodcastRepository`) bridges this. Ensure no `@Published` mutations happen off the main actor — schedule them via `DispatchQueue.main.async`.

4. **PlaylistFeature → Persistence dependency** — This adds a second dependency path from feature to persistence. If this feels heavy, an alternative is to keep PlaylistFeature pure and inject a `PlaylistManaging`-conforming object from the app target (no direct Persistence import in the feature package). The plan currently takes the direct dependency approach for simplicity, matching how `LibraryFeature` depends on `Persistence`.

5. **Context menu on episode rows** — `EpisodeListView` already has swipe actions on both edges. Adding a `.contextMenu` is additive and doesn't conflict, but it must present a sheet (for playlist selection) which requires `@State` management in the view or viewmodel.

## Validation Criteria

- [ ] **Syntax gate passes**: `./scripts/run-xcode-tests.sh -s` — confirms Swift 6 strict concurrency compliance for all new code
- [ ] **Persistence CRUD**: `PlaylistRepositoryTests` — create, read, update, delete playlists with in-memory `ModelContainer`; verify `toDomain()`/`fromDomain()` roundtrip preserves all fields including episode order
- [ ] **Duplicate prevention**: Persistence test — attempting to create a playlist with an existing ID is a no-op; adding a duplicate episode ID to a playlist is rejected
- [ ] **Episode reorder**: Persistence test — `reorderEpisodes(in:from:to:)` correctly handles `IndexSet` → `toOffset` semantics matching SwiftUI's `.onMove`
- [ ] **ViewModel state transitions**: `PlaylistViewModelTests` — creating a playlist updates `playlists` array; deleting removes it; episode resolution returns correct `[Episode]` for given playlist
- [ ] **Protocol conformance**: Both `InMemoryPlaylistManager` and `SwiftDataPlaylistRepository` compile and conform to `PlaylistManaging` without warnings
- [ ] **App wiring**: Building `zpod` target (`./scripts/run-xcode-tests.sh -b zpod`) succeeds — confirms schema registration, dependency injection, and import graph are correct
- [ ] **Playlists persist across restart**: Manual verification — create playlist, kill app, relaunch, playlist still present (SwiftData storage)
- [ ] **UI test: create playlist**: `PlaylistCreationUITests` — tap "+", enter name, tap Create, verify playlist appears in list
- [ ] **UI test: delete playlist**: swipe-to-delete, verify playlist removed
- [ ] **UI test: add episode to playlist**: navigate to episode list, long-press episode, tap "Add to Playlist", select playlist, verify episode count increases
- [ ] **Accessibility**: All new interactive elements have `accessibilityIdentifier` set using `.matching(identifier:).firstMatch` pattern in tests
- [ ] **Full regression**: `./scripts/run-xcode-tests.sh` (no flags) — all existing tests still pass, no regressions introduced
- [ ] **CI compatibility**: New tests are self-supporting — they create their own state, don't depend on persisted data from prior runs (use in-memory `ModelContainer` or `InMemoryPlaylistManager`)

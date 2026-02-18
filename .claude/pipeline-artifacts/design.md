I'm running in a restricted permission mode that prevents writing files. Since this is a design/planning pipeline stage, I'll present the Architecture Decision Record directly in the conversation output.

`★ Insight ─────────────────────────────────────`
**Why the plan was blocked**: The pipeline is running in "don't ask" mode with file writes denied. This is the same restriction that stalled the autonomous loop for 27 iterations. The ADR will be presented inline — the pipeline operator will need to persist it to `.claude/pipeline-artifacts/design.md`.
`─────────────────────────────────────────────────`

---

# Design: 06.1.1 Core Playlist Creation and Management

## Context

The zpod iOS podcast app needs interactive playlist management — users currently see read-only playlist lists but cannot create, edit, reorder, or delete playlists from the UI. The backend infrastructure is largely complete: `PlaylistManaging` protocol, `SwiftDataPlaylistRepository` (production), `InMemoryPlaylistManager` (test double), and the `Playlist`/`SmartPlaylist` domain models all exist. The gap is the interactive UI layer and its backing ViewModel, plus a critical Swift 6 concurrency bug that blocks compilation.

### Critical Blocker: Swift 6 Conformance

`InMemoryPlaylistManager` (`Packages/CoreModels/Sources/CoreModels/InMemoryPlaylistManager.swift`) is annotated `@MainActor` yet conforms to `PlaylistManaging: Sendable`. Under Swift 6 strict concurrency (the package uses `swift-tools-version: 6.0`), a `@MainActor` class cannot satisfy a `Sendable` conformance because actor isolation restricts where methods can be called from, violating the "usable from any context" contract of `Sendable`. The previous autonomous pipeline stalled for **27 iterations** trying to fix this but was denied write permissions.

### Constraints

- **Swift 6.1.2 strict concurrency** — no escape hatches; conformance must be clean.
- **iOS 18+ deployment target** — Observation framework (`@Observable`) available.
- **Package architecture**: `SharedUtilities → CoreModels → Persistence → PlaylistFeature → LibraryFeature → App`.
- `PlaylistManaging` is a synchronous protocol with no async methods and no change streams.
- `SwiftDataPlaylistRepository` already uses `@unchecked Sendable` + serial `DispatchQueue` — the established production pattern.
- The existing `PlaylistFeatureView` is purely data-driven (receives `[Playlist]` as parameter), with no mutation affordances.

## Decision

### 1. Fix `InMemoryPlaylistManager` to `@unchecked Sendable` (matching production pattern)

Remove `@MainActor` isolation. Make `InMemoryPlaylistManager` a `final class` conforming to `PlaylistManaging, @unchecked Sendable`. This mirrors `InMemoryPodcastManager` in TestSupport and `SwiftDataPlaylistRepository` in Persistence — both use `@unchecked Sendable` because they manage mutable state internally but guarantee safety through either single-threaded test usage or serial queues. The `#if canImport(Combine)` branching with `ObservableObject` will be removed — the Combine publishers are unused (no subscribers exist anywhere in the codebase) and the dual-implementation creates maintenance burden.

**Rationale**: The protocol requires `Sendable`. `@MainActor` is too restrictive — it forces all callers onto the main thread, which the protocol doesn't guarantee. `@unchecked Sendable` is the established codebase pattern for both test doubles and production repositories.

### 2. Add `description` field to `Playlist` model

Add `public let description: String` (default `""`) to the `Playlist` struct in `Packages/CoreModels/Sources/CoreModels/Playlist.swift`. The property name `description` is safe because `Playlist` does not conform to `CustomStringConvertible`. Add a `withDescription(_:)` builder method following the existing `withName(_:)` / `withEpisodes(_:)` pattern. Update `PlaylistEntity` in `Packages/Persistence/Sources/Persistence/PlaylistEntity.swift` with a `playlistDescription` stored property (avoiding the SwiftData/`description` naming collision) and update `toDomain()` / `fromDomain()` / `updateFrom()` accordingly.

### 3. Introduce `PlaylistViewModel` as `@MainActor @Observable`

Create a new `PlaylistViewModel` in the PlaylistFeature package. It holds a reference to `any PlaylistManaging` and exposes:

- `playlists: [Playlist]` — read from manager, drives the list view
- CRUD methods: `createPlaylist(name:description:)`, `deletePlaylist(id:)`, `duplicatePlaylist(id:)`, `renamePlaylist(id:name:)`, `updateDescription(id:description:)`
- Episode management: `addEpisodes(_:to:)`, `removeEpisode(_:from:)`, `reorderEpisodes(in:from:to:)`

After every mutation, the ViewModel calls `refreshPlaylists()` which re-reads `allPlaylists()` from the manager. This pull-based refresh is simple and correct — the `PlaylistManaging` protocol is synchronous without change streams.

**Why `@Observable` over `ObservableObject`**: The project targets iOS 18+. `@Observable` (Observation framework) provides finer-grained view invalidation — views only re-render when the specific properties they read change. This matches `StorageManagementViewModel` (`Packages/LibraryFeature/Sources/LibraryFeature/StorageManagement/StorageManagementViewModel.swift`), the existing ViewModel precedent in the codebase.

### 4. Interactive UI: Creation Sheet, Add-to-Playlist Sheet, Inline Editing

**PlaylistCreationView** — A `.sheet` presentation with:
- Text field for playlist name (required, disables Save when empty)
- Optional text field for description
- Supports both create and edit modes via an optional `existingPlaylist` parameter
- On save: calls ViewModel create or rename+updateDescription

**AddToPlaylistView** — A `.sheet` accepting `episodeIds: [String]`:
- Lists all playlists with tap-to-add (checkmark for playlists already containing the episodes)
- "New Playlist" row at top that presents `PlaylistCreationView` inline
- Prepared for integration from episode context menus (actual context menu wiring deferred)

**PlaylistFeatureView upgrades** (`Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistViews.swift`):
- Toolbar `+` button presents `PlaylistCreationView`
- `.onDelete` swipe on playlist rows → ViewModel `deletePlaylist`
- Context menu on each row: Edit, Duplicate, Delete

**PlaylistDetailView upgrades** (same file):
- `.onMove` modifier for drag-and-drop episode reordering in Edit mode
- Swipe-to-remove on individual episode rows
- `EditButton` in toolbar to toggle reorder mode

### 5. ContentView integration changes

`PlaylistTabView` in `Packages/LibraryFeature/Sources/LibraryFeature/ContentView.swift` will construct a `PlaylistViewModel` from the injected `playlistManager` and pass it to the upgraded `PlaylistFeatureView`. The `episodesProvider` closure continues to resolve episode IDs to `Episode` objects — this lookup responsibility stays in LibraryFeature where podcast data is available.

### 6. Data flow architecture

```
┌─────────────┐     ┌──────────────────┐     ┌───────────────────┐
│ SwiftUI View │────▶│ PlaylistViewModel│────▶│ PlaylistManaging   │
│ (reads state)│     │ @MainActor       │     │ (protocol)         │
│              │◀────│ @Observable      │◀────│                    │
│              │     │                  │     │ SwiftDataPlaylist- │
│              │     │ playlists: [P]   │     │ Repository (prod)  │
│              │     │ create/delete/   │     │ InMemoryPlaylist-  │
│              │     │ duplicate/reorder│     │ Manager (test)     │
└─────────────┘     └──────────────────┘     └───────────────────┘
      │                     │
      │ .sheet              │ refreshPlaylists()
      ▼                     │ (pull after mutate)
┌─────────────┐             │
│ Creation/   │─────────────┘
│ AddTo Sheet │
└─────────────┘
```

## Alternatives Considered

### 1. Keep `@MainActor` on `InMemoryPlaylistManager`, make protocol methods `@MainActor`

**Pros**: No `@unchecked Sendable` annotation needed; explicit isolation throughout.
**Cons**: Would require changing `PlaylistManaging` protocol to add `@MainActor` to every method signature. This breaks `SwiftDataPlaylistRepository` which runs on a serial `DispatchQueue` (not MainActor). It would also break the established `PodcastManaging` pattern (synchronous, `Sendable`, no actor annotation). **Rejected** — cascading protocol change contradicts existing architecture.

### 2. Use `ObservableObject` + `@Published` for the ViewModel

**Pros**: Familiar to older SwiftUI codebases; doesn't require iOS 17+.
**Cons**: Project targets iOS 18+. `@Observable` is the modern replacement with better performance. `StorageManagementViewModel` already uses `@Observable`, establishing project convention. **Rejected** — inconsistent with existing patterns.

### 3. Add `AsyncStream<PlaylistChange>` to `PlaylistManaging` for reactive updates

**Pros**: ViewModel could subscribe to change events instead of pull-after-mutate; enables multi-writer scenarios.
**Cons**: Over-engineering — only one writer (the UI) exists. `PlaylistChange` enum exists in `Playlist.swift` but nothing consumes it. Adding reactive streams would require changes to both repository implementations. **Deferred** to a future issue when multi-writer or background sync is needed.

### 4. Merge `PlaylistFeatureView` and `PlaylistDetailView` into a single combined view

**Pros**: Fewer files.
**Cons**: Violates single-responsibility — list and detail have different layouts, toolbars, and interaction patterns. **Rejected**.

## Implementation Plan

### Files to create (4 new files)
- `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistViewModel.swift`
- `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistCreationView.swift`
- `Packages/PlaylistFeature/Sources/PlaylistFeature/AddToPlaylistView.swift`
- `Packages/PlaylistFeature/Tests/PlaylistFeatureTests/PlaylistViewModelTests.swift`

### Files to modify (6 existing files)
- `Packages/CoreModels/Sources/CoreModels/InMemoryPlaylistManager.swift` — Remove `@MainActor`, consolidate to single `@unchecked Sendable` implementation, drop Combine branching
- `Packages/CoreModels/Sources/CoreModels/Playlist.swift` — Add `description` property + `withDescription(_:)` builder
- `Packages/Persistence/Sources/Persistence/PlaylistEntity.swift` — Add `playlistDescription` stored property, update conversion methods
- `Packages/PlaylistFeature/Sources/PlaylistFeature/PlaylistViews.swift` — Add toolbar create button, swipe-delete, context menus, `.onMove` for episodes, `EditButton`
- `Packages/LibraryFeature/Sources/LibraryFeature/ContentView.swift` — Update `PlaylistTabView` to construct and pass `PlaylistViewModel`
- `Packages/PlaylistFeature/Tests/PlaylistFeatureTests/PlaylistFeatureTests.swift` — Replace stub test or keep as smoke test alongside new test file

### Dependencies
- **No new package dependencies.** PlaylistFeature already depends on CoreModels and SharedUtilities. The ViewModel uses `any PlaylistManaging` (from CoreModels).
- CoreModels' `CombineSupport` dependency may become orphaned after removing Combine from `InMemoryPlaylistManager` — but other files in CoreModels may still use it, so **do not remove the package dependency** without auditing all imports.

### Risk areas

1. **`InMemoryPlaylistManager` Combine removal** — Must grep for `playlistsChanged` across the entire codebase to confirm nothing subscribes. If anything does, the Combine support must be preserved (but made `@unchecked Sendable`).

2. **SwiftData migration for `playlistDescription`** — Adding `var playlistDescription: String = ""` with a default value is a lightweight schema migration SwiftData handles automatically. Non-optional without a default would crash on existing databases.

3. **`PlaylistFeatureView` API change** — The view currently takes `playlists: [Playlist]` as a parameter. After adding ViewModel support, its initializer changes. `ContentView` is the only caller (confirmed by grep), so blast radius is contained.

4. **`description` property naming** — `Playlist` doesn't conform to `CustomStringConvertible`, so no conflict. Minor future risk if someone adds that conformance later.

## Validation Criteria

- [ ] `./scripts/run-xcode-tests.sh -s` passes (syntax gate — confirms Swift 6 conformance fix)
- [ ] `./scripts/run-xcode-tests.sh -b zpod` builds successfully (workspace build)
- [ ] `InMemoryPlaylistManager` uses `@unchecked Sendable` without `@MainActor`
- [ ] `Playlist` model has `description: String` field with default `""`
- [ ] `PlaylistEntity` has `playlistDescription` field with round-trip conversion verified
- [ ] `PlaylistViewModel` CRUD tests pass: create, delete, duplicate, rename, add episode, remove episode, reorder
- [ ] `PlaylistFeatureView` shows `+` toolbar button that presents creation sheet
- [ ] Swipe-to-delete works on playlist rows
- [ ] Context menu offers Edit, Duplicate, Delete on each playlist row
- [ ] `PlaylistDetailView` supports `.onMove` drag-and-drop in Edit mode
- [ ] Swipe-to-remove works on episode rows in detail view
- [ ] `AddToPlaylistView` lists playlists with checkmarks for existing membership
- [ ] All new views have accessibility identifiers following project conventions (e.g., `Playlist.CreateButton`, `Playlist.Row.<id>`)
- [ ] No force unwraps in production code
- [ ] `IntegrationTests/PlaylistPlaybackIntegrationTests` continue passing (regression)
- [ ] `./scripts/run-xcode-tests.sh` full regression passes
- [ ] No Combine imports remain in `InMemoryPlaylistManager` (or if kept, conformance is clean)

---

`★ Insight ─────────────────────────────────────`
**Key architectural takeaways from this ADR**:
- The `@MainActor` + `Sendable` conflict is a common Swift 6 migration trap. The lesson: protocols requiring `Sendable` should not have conforming types pinned to a specific actor unless the protocol itself is actor-isolated. The zpod codebase already solved this in `SwiftDataPlaylistRepository` and `InMemoryPodcastManager` — the fix is to align `InMemoryPlaylistManager` with those precedents.
- The pull-based refresh pattern (mutate → re-read) is intentionally simple. Reactive streams via `AsyncStream<PlaylistChange>` would be more elegant but introduce complexity without a current consumer. The `PlaylistChange` enum is already defined and ready for when that future need arises.
- `@Observable` over `ObservableObject` is a one-way door for iOS 18+ projects — once adopted, going back adds boilerplate. The project already crossed this threshold with `StorageManagementViewModel`.
`─────────────────────────────────────────────────`

---

**Note**: I was unable to write this ADR to `.claude/pipeline-artifacts/design.md` because file write permissions are denied in the current pipeline mode. To proceed with the build stage, this content needs to be persisted to that file.

---
goal: "06.1.1 Core Playlist Creation and Management

## Plan Summary
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
[... full plan in .claude/pipeline-artifacts/plan.md]

## Key Design Decisions
# Design: 06.1.1 Core Playlist Creation and Management
## Context
## Decision
### 1. Protocol Extraction: `PlaylistManaging`
### 2. SwiftData Persistence: `PlaylistEntity` + `SwiftDataPlaylistRepository`
### 3. ViewModel Layer
### 4. UI Views
### 5. App Wiring
### 6. Episode Addition Entry Point
### 7. Data Flow
[... full design in .claude/pipeline-artifacts/design.md]

Historical context (lessons from previous pipelines):
{"error":"intelligence_disabled","results":[]}

Task tracking (check off items as you complete them):
# Pipeline Tasks — 06.1.1 Core Playlist Creation and Management

## Implementation Checklist
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
- [ ] Playlist creation/editing completes within 500ms
- [ ] Drag-and-drop reordering works smoothly with 20+ episodes
- [ ] Episode addition succeeds from episode list context menu
- [ ] Playlist playback integrates with existing player (Play All, Shuffle)
- [ ] Playlists persist across app restarts (SwiftData)

## Context
- Pipeline: ios-harness
- Branch: feat/06-1-1-core-playlist-creation-and-manage-186
- Issue: #186
- Generated: 2026-02-17T01:52:38Z"
iteration: 16
max_iterations: 25
status: running
test_cmd: "./scripts/run-xcode-tests.sh 2>&1"
model: opus
agents: 1
started_at: 2026-02-17T19:10:43Z
last_iteration_at: 2026-02-17T19:10:43Z
consecutive_failures: 0
total_commits: 16
audit_enabled: true
audit_agent_enabled: true
quality_gates_enabled: true
dod_file: "/Volumes/zHardDrive/code/zpod/.claude/pipeline-artifacts/dod.md"
auto_extend: true
extension_count: 0
max_extensions: 3
---

## Log
### Iteration 1 (2026-02-17T12:37:25Z)
**What I need permission for:**
- **Write tool**: To create new Swift source files and edit existing ones
- **Bash tool**: To run `./scripts/run-xcode-tests.sh -s` (syntax gate), build verification, and git commits

### Iteration 2 (2026-02-17T13:46:21Z)
### Recommended Permission Setup
The loop should be configured with at least:
- **Write/Edit**: Allowed for `.swift` files and `Package.swift` within the `/Volumes/zHardDrive/code/zpod/` workspace

### Iteration 3 (2026-02-17T14:55:41Z)
**To the pipeline operator**: Please re-run this iteration with permissions enabled for:
- Write (for `.swift` and `Package.swift` files in `/Volumes/zHardDrive/code/zpod/`)
- Edit (same scope)

### Iteration 4 (2026-02-17T16:06:47Z)
- `ContentView.swift:159` — hardcoded empty arrays to replace
- `ZpodApp.swift:87-99` — ModelContainer schema to extend
- `SwiftDataPodcastRepository.swift` — serial-queue pattern to replicate

### Iteration 5 (2026-02-17T17:16:41Z)
Write: allowed for *.swift and Package.swift in /Volumes/zHardDrive/code/zpod/
Edit: allowed for same scope
Bash: allowed for ./scripts/run-xcode-tests.sh and git commands

### Iteration 6 (2026-02-17T18:27:08Z)
Please re-run this iteration with these permissions:
- **Write tool**: allowed for `*.swift` and `Package.swift` files in `/Volumes/zHardDrive/code/zpod/`
- **Edit tool**: allowed for same scope

### Iteration 7 (2026-02-17T18:40:43Z)
**Files modified** (3):
- `InMemoryPlaylistManager.swift` — Added `PlaylistManaging` conformance
- `ContentView.swift` — Wired `playlistManager` through to `PlaylistTabView`

### Iteration 8 (2026-02-17T18:43:20Z)
### Remaining work after this fix
1. Run syntax check to verify the fix compiles
2. Add persistence unit tests (audit finding)

### Iteration 9 (2026-02-17T18:45:55Z)
Alternatively, you can apply the 2-line change manually:
1. Open `Packages/CoreModels/Sources/CoreModels/InMemoryPlaylistManager.swift`
2. **Line 7-8**: Remove `@MainActor` line, change `public class InMemoryPlaylistManager: ObservableObject, PlaylistManag

### Iteration 10 (2026-02-17T18:49:36Z)
The `PlaylistManaging` protocol is `Sendable` with nonisolated method requirements. `@MainActor` on the class makes all 
### To unblock the loop
Either:

### Iteration 11 (2026-02-17T18:52:18Z)
- PlaylistManaging protocol + SwiftData persistence
- ContentView wired to live playlist data
- App-level dependency injection complete

### Iteration 12 (2026-02-17T18:55:56Z)
2. `PlaylistCreationView` + `PlaylistEditView` sheets
3. `AddToPlaylistView` for episode addition
4. Playlist playback integration

### Iteration 13 (2026-02-17T19:00:08Z)
**Why this works**: The `PlaylistManaging` protocol requires `Sendable` with `nonisolated` methods. `@MainActor` makes a
### To unblock me, either:
1. **Grant Edit/Write permissions** for this session so I can apply the fix and continue building the playlist feature

### Iteration 14 (2026-02-17T19:04:29Z)
### How to unblock
Please either:
1. **Grant Edit/Write permissions** for this session so I can apply the fix and continue

### Iteration 15 (2026-02-17T19:08:22Z)
`─────────────────────────────────────────────────`
### How to unblock
Please either:

### Iteration 16 (2026-02-17T19:10:43Z)
### To Unblock
Please either:
1. **Apply the fix manually** using the two changes above, OR


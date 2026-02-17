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
- Generated: 2026-02-17T01:52:38Z

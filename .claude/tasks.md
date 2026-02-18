# Tasks — 06.1.1 Core Playlist Creation and Management

## Status: In Progress
Pipeline: autonomous | Branch: feat/06-1-1-core-playlist-creation-and-manage-186

## Checklist
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
- [ ] `InMemoryPlaylistManager` compiles without Swift 6 concurrency errors
- [ ] `Playlist` model includes description field
- [ ] Users can create playlists from the Playlists tab via "+" toolbar button
- [ ] Users can edit playlist name/description from detail view
- [ ] Users can delete playlists via swipe or context menu
- [ ] Users can duplicate playlists via context menu
- [ ] Users can reorder episodes via drag-and-drop (Edit mode)

## Notes
- Generated from pipeline plan at 2026-02-18T02:04:32Z
- Pipeline will update status as tasks complete

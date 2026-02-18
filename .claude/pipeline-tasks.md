# Pipeline Tasks — 06.1.1 Core Playlist Creation and Management

## Implementation Checklist
- [ ] Task 1: Add `description` field to `Playlist` model with backward-compatible default
- [ ] Task 2: Add `playlistDescription` field to `PlaylistEntity` and update conversions
- [ ] Task 3: Fix `InMemoryPlaylistManager` Swift 6 concurrency (remove `@MainActor`, add lock)
- [ ] Task 4: Create `PlaylistViewModel` with CRUD, reorder, duplicate, episode resolution
- [ ] Task 5: Create `PlaylistCreationView` sheet for creating and editing playlists
- [ ] Task 6: Create `AddToPlaylistView` sheet for adding episodes to playlists
- [ ] Task 7: Upgrade `PlaylistFeatureView` with toolbar create, swipe-delete, context menus
- [ ] Task 8: Upgrade `PlaylistDetailView` with drag-and-drop reordering and swipe-to-remove
- [ ] Task 9: Update `ContentView.PlaylistTabView` to use ViewModel with real episode resolution
- [ ] Task 10: Write comprehensive `PlaylistViewModel` unit tests
- [ ] Task 11: Run syntax check and fix Swift 6 issues
- [ ] Task 12: Run targeted package tests and full regression
- [ ] Task 13: Create dev-log entry
- [ ] `Playlist` model includes `description` field with backward-compatible defaults
- [ ] `PlaylistEntity` persists description through SwiftData
- [ ] `InMemoryPlaylistManager` compiles without Swift 6 concurrency errors
- [ ] Users can create playlists from Playlists tab via "+" toolbar button
- [ ] Users can edit playlist name/description
- [ ] Users can delete playlists via swipe or context menu
- [ ] Users can duplicate playlists via context menu

## Context
- Pipeline: autonomous
- Branch: feat/06-1-1-core-playlist-creation-and-manage-186
- Issue: #186
- Generated: 2026-02-18T23:44:49Z

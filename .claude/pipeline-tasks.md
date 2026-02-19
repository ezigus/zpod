# Pipeline Tasks — 06.1.1 Core Playlist Creation and Management

## Implementation Checklist
- [ ] Task 1: Add `addEpisodes(_:to:)` batch method to `PlaylistViewModel`
- [ ] Task 2: Create `AddToPlaylistView` sheet in PlaylistFeature
- [ ] Task 3: Wire `episodeProvider` into `PlaylistTabView` in ContentView
- [ ] Task 4: Create `PlaylistTests.swift` unit tests in CoreModels
- [ ] Task 5: Add batch-add tests to `PlaylistFeatureTests`
- [ ] Task 6: Run syntax check and fix any issues
- [ ] Task 7: Run targeted tests for PlaylistFeature and CoreModels
- [ ] Task 8: Run full regression suite
- [ ] Task 9: Update `.claude/tasks.md` and `.claude/pipeline-tasks.md`
- [ ] Task 10: Commit all changes
- [x] `Playlist` model has `description` field with backward-compatible defaults
- [x] `PlaylistEntity` persistence includes `playlistDescription` with domain conversion
- [x] `PlaylistManaging` includes `duplicatePlaylist` method, implemented in manager + repository
- [x] `PlaylistViewModel` provides reactive CRUD, reorder, and episode management
- [x] `PlaylistCreationView` allows creating/editing playlists with name + description
- [ ] `AddToPlaylistView` allows adding episodes to playlists from various contexts
- [ ] Batch episode addition works (multiple episodes at once)
- [ ] CoreModels playlist unit tests pass
- [ ] PlaylistFeature ViewModel tests pass (including new batch tests)
- [ ] Full regression suite passes with zero failures

## Context
- Pipeline: autonomous
- Branch: feat/06-1-1-core-playlist-creation-and-manage-186
- Issue: #186
- Generated: 2026-02-19T11:30:42Z

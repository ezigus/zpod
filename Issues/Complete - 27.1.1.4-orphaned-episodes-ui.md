# Issue 27.1.1.4: Orphaned Episodes UI

## Priority
Low

## Status
Complete

## Description
Implement a UI section to display and manage "orphaned" episodes—episodes that have been removed from podcast RSS feeds but were preserved because they contain user state (playback position, downloads, favorites, bookmarks, archived status, or ratings).

Currently, when a feed refresh removes episodes, the sync logic in `SwiftDataPodcastRepository.update()` (Issue 27.1.1.2) correctly preserves episodes with user state. However, these orphaned episodes become invisible to users since they no longer appear in normal episode lists (which are derived from the current feed).

This issue addresses the user experience gap by providing visibility into orphaned episodes and allowing users to manage them.

## Background
From Issue 27.1.1.2 Known Limitations:
> Orphaned episodes (removed from feed but have user state) will not appear in normal episode lists.
> Future enhancement: UI to manage orphaned episodes (e.g., "Archived Episodes" section).

## Acceptance Criteria
- [x] Users can view a list of orphaned episodes (episodes with user state that are no longer in the feed)
- [x] Orphaned episodes section accessible from Library or Settings
- [x] Each orphaned episode shows:
  - Episode title and podcast name
  - User state indicators (playback progress, downloaded, favorited, etc.)
  - Reason for preservation (e.g., "Has playback progress", "Downloaded")
- [x] Users can manually delete individual orphaned episodes
- [x] Users can bulk-delete all orphaned episodes (with confirmation)
- [x] Users can play orphaned episodes (if audio URL still valid)
- [x] Clear empty state when no orphaned episodes exist

## Implementation Approach

### Data Layer
```swift
// Add to PodcastManaging protocol or create dedicated query
func fetchOrphanedEpisodes() -> [Episode]

// Implementation in SwiftDataPodcastRepository
func fetchOrphanedEpisodes() -> [Episode] {
    // Episodes where:
    // 1. hasUserState == true
    // 2. Episode ID not in any current podcast's feed episodes
    // This requires tracking which episodes are "feed-current" vs "orphaned"
}
```

### Schema Enhancement Option
Consider adding an `isOrphaned: Bool` flag to `EpisodeEntity` that gets set to `true` when an episode is preserved during sync but removed from feed. This simplifies queries:

```swift
// In EpisodeEntity
public var isOrphaned: Bool  // Set during sync when episode removed from feed but kept

// Query becomes simple
let predicate = #Predicate<EpisodeEntity> { $0.isOrphaned && $0.hasUserState }
```

### UI Components
1. **OrphanedEpisodesView** - Main list view
2. **OrphanedEpisodeRow** - Individual episode display with state indicators
3. **Entry point** - Add to Library tab or Settings > Storage

### Navigation Options
| Location | Pros | Cons |
|----------|------|------|
| Library > "Orphaned" section | Discoverable, near episodes | Clutters Library |
| Settings > Storage | Logical grouping with cleanup | Less discoverable |
| Library > Filter option | Consistent with other filters | May be overlooked |

## Edge Cases
- Orphaned episode's audio URL may be invalid (feed removed it)
- Episode may become "un-orphaned" if feed re-adds it
- Large number of orphaned episodes (pagination/performance)
- Podcast itself was unsubscribed (cascade delete should handle)

## Testing Strategy

### Unit Tests
- `testFetchOrphanedEpisodesReturnsOnlyOrphaned`
- `testFetchOrphanedEpisodesExcludesFeedCurrentEpisodes`
- `testDeleteOrphanedEpisodeRemovesFromDatabase`
- `testOrphanedEpisodeCanStillPlay` (if URL valid)

### UI Tests
- Navigate to orphaned episodes section
- Verify orphaned episodes display correctly
- Delete single orphaned episode
- Bulk delete with confirmation
- Empty state displays when no orphaned episodes

## Dependencies
- **Requires**: Issue 27.1.1.2 (Episode Sync) - COMPLETE
- **Blocks**: None

## Estimated Effort
4-6 hours

## Success Metrics
- Users can discover and manage orphaned episodes
- Storage can be reclaimed by deleting unwanted orphaned episodes
- No data loss—users explicitly choose to delete

## Related Issues
- Issue 27.1.1.2 - Episode Sync (Upsert Rules) - prerequisite, defines orphan behavior
- Issue 27.1 - Podcast Persistence Foundation (parent epic)

## Design Mockup (Conceptual)

```
┌─────────────────────────────────────┐
│ ← Orphaned Episodes                 │
├─────────────────────────────────────┤
│ These episodes were removed from    │
│ their podcast feeds but kept        │
│ because you have progress or data.  │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ Episode Title                   │ │
│ │ Podcast Name • 45:30 remaining  │ │
│ │ [▶️ Progress] [⬇️ Downloaded]    │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ Another Episode                 │ │
│ │ Other Podcast • ⭐ Favorited     │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ [Delete All Orphaned Episodes]      │
└─────────────────────────────────────┘
```

## Completion Summary

**Completed**: 2026-02-02
**PR**: #388

### Implementation Highlights
- Added `isOrphaned: Bool` property to `EpisodeEntity` and `Episode` model
- Implemented `fetchOrphanedEpisodes()` in `SwiftDataPodcastRepository`
- Created `OrphanedEpisodesView` and `OrphanedEpisodesViewModel` in LibraryFeature package
- Added Settings › Storage navigation entry with badge showing orphan count
- Implemented per-episode and bulk delete operations with confirmation
- Added comprehensive test coverage:
  - Unit tests in `OrphanedEpisodesViewModelTests`
  - Persistence tests in `SwiftDataPodcastRepositoryTests`
  - UI tests in `OrphanedEpisodesUITests`
  - Integration tests in `OrphanedEpisodesIntegrationTests`

### UI Features
- Badge on Settings › Storage showing orphan count
- List view with episode metadata (title, podcast, preserved state)
- Swipe-to-delete for individual episodes
- "Delete All" button with confirmation alert
- Empty state when no orphaned episodes exist
- Test seeding support via `UITEST_SEED_ORPHANED_EPISODES` environment variable

### Testing Infrastructure
- UI test seeding helper `seedOrphanedEpisode()` in ZpodApp
- Integration test support in `SwiftDataPodcastRepository`
- Page object pattern used in `SettingsScreen` for navigation

## Notes
- Consider periodic notification if orphaned episodes exceed a threshold (e.g., "You have 50+ orphaned episodes taking up space") - deferred
- Audio playback may fail if publisher removed the audio file—handle gracefully with error message - existing error handling sufficient

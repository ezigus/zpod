# Issue 02.1.3.2: Episode Status Visualisation & Progress Controls

## Priority
High

## Status
🔄 Planned

## Description
Complete Phase 2 of the batch-operations initiative by delivering real-time status visuals and controls for individual episodes during bulk operations. This includes accurate download/playback progress, pause/resume and quick-play affordances, richer status iconography, and actionable success/failure summaries surfaced to the user.

## Acceptance Criteria

### Scenario 1: Accurate Download Progress
- **Given** episodes are downloading or queued via batch operations
- **When** I view the episode list
- **Then** each downloading episode shows a live progress bar (0–100%) sourced from the download manager
- **And** tapping the progress affordance exposes pause/resume actions with immediate feedback

### Scenario 2: Playback Status Feedback
- **Given** episodes are partially played or marked played/unplayed via batch operations or single taps
- **When** I inspect the list
- **Then** playback icons animate between states and display percentage progress based on `playbackPosition`
- **And** the quick-play control resumes from the stored position and reflects completion once playback ends

### Scenario 3: Error Handling & Notifications
- **Given** a batch operation fails for one or more episodes
- **When** the failure occurs
- **Then** the progress HUD surfaces error-specific messaging, retry affordances, and optional undo actions where supported
- **And** a lightweight toast/banner summarises success or failure once the batch completes

### Scenario 4: Accessibility & Persistence
- **Given** I rely on VoiceOver or Dynamic Type
- **When** I interact with status icons, progress bars, or pause/resume buttons
- **Then** each control exposes descriptive labels, values, and traits
- **And** status state persists across navigation, filtering, and app relaunches (synced with persistence layer)

## Implementation Approach
1. **Live Progress Integration**
   - Bridge `BatchOperationManager` and the download subsystem to publish granular progress events per episode
   - Replace placeholder progress values with real metrics and expose pause/resume callbacks in the row view
2. **Playback & Status UI**
   - Extend `EpisodeRowView` with animated state transitions, quick-play entry points, and clarified iconography (played/in-progress/archived/rated)
   - Wire `EpisodeListViewModel` to update persistence and emit state changes upon quick-play completion or pause/resume actions
3. **User Feedback Loop**
   - Add toast/banner infrastructure to summarise batch completion, including success/failure counts and retry/undo CTA when relevant
   - Harden undo pathways to reverse reversible operations and refresh the list in-place
4. **Accessibility & Persistence**
   - Audit accessibility identifiers/labels for new controls, ensuring VoiceOver announces progress and actions correctly
   - Persist download/playback status updates through the appropriate repositories so UI state survives reloads

## Specification References
- `downloads.md` – Download progress indicators & controls
- `ui.md` – Status iconography and accessibility guidelines
- `content.md` – Episode status management expectations

## Dependencies
- **Required**: Issue 02.1.3.1 – Multi-selection & batch interface (builds on existing batch queue and selection state)

## Estimated Effort
**Complexity**: High  
**Time Estimate**: 2 weeks  
**Story Points**: 13

## Success Metrics
- Download progress bars update within 100 ms of backend updates
- Pause/resume actions reflect new status within 200 ms and survive navigation
- Batch completion banners show within 1 second of operation end with actionable CTAs
- Accessibility audits (VoiceOver + Dynamic Type) pass for all status-related controls

## Testing Strategy
- **Unit Tests**: Episode status mutation helpers, undo pathways, download progress adapters
- **Integration Tests**: Batch + download subsystems exercising pause/resume and progress persistence
- **UI Tests**: VoiceOver navigation of status controls, quick-play flows, toast/banner presentation
- **Performance Tests**: Rendering cost of progress updates across 50+ visible episodes stays < 16 ms/frame

---
goal: "[#27.1.9] Wire Library View to Live Podcast Repository Data

## Plan Summary
`★ Insight ─────────────────────────────────────`
The key architectural insight here is the **XCUITest quiescence constraint**. SwiftUI's `.onAppear` runs on the main actor, and `podcastManager.all()` is a synchronous call. Wrapping it in `Task { @MainActor }` would create an async task submission that XCUITest's quiescence detector can't see through — causing "Waiting for app to idle" hangs. The `.onAppear` re-query pattern (Approach A) is specifically chosen because tab switches naturally trigger `.onAppear`, giving us "free" reactivity without Combine/AsyncStream complexity.
`─────────────────────────────────────────────────`

---

# Implementation Plan: 27.1.9 — Wire Library View to Live Podcast Repository Data

**Issue**: #426  
**Branch**: `feat/-27-1-9-wire-library-view-to-live-podcas-426`

---

## Socratic Design Refinement

### Requirements Clarity

**Minimum viable change**: Replace the hardcoded `samplePodcasts` array in `LibraryView` with a call to `podcastManager.all()`, add an empty-state view, and ensure the list refreshes when the user switches back to the Library tab from Discover.

**Implicit requirements**:
[... full plan in .claude/pipeline-artifacts/plan.md]

## Key Design Decisions
# Architecture Decision Record: [#27.1.9] Wire Library View to Live Podcast Repository Data
## Context
## Decision
## Alternatives Considered
### 1. **Combine/AsyncStream Observation** (Rejected)
### 2. **Lazy Refresh via `onChange(of: tabSelection)`** (Rejected)
### 3. **Cached Snapshot with Pull-to-Refresh** (Rejected)
## Implementation Plan
### Files to Create
### Files to Modify
[... full design in .claude/pipeline-artifacts/design.md]

Historical context (lessons from previous pipelines):
{"status":"disabled","error":"intelligence_disabled","results":[]}
[38;2;0;212;255m[1m▸[0m Intelligence disabled — using data-driven fallbacks

Discoveries from other pipelines:
[38;2;0;212;255m[1m▸[0m No new discoveries to inject

Task tracking (check off items as you complete them):
# Pipeline Tasks — [#27.1.9] Wire Library View to Live Podcast Repository Data

## Implementation Checklist
- [x] Task 1: Add `podcastManager: PodcastManaging` property to `LibraryView`
- [x] Task 2: Thread dependency from `ContentView` init to `LibraryView` call site
- [x] Task 3: Replace hardcoded `samplePodcasts` with `podcastManager.all()` in `.onAppear`
- [x] Task 4: Add `isLoading` state gate with `ProgressView`
- [x] Task 5: Add `ContentUnavailableView` empty state with accessibility identifier
- [x] Task 6: Add `UITEST_SEED_PODCASTS` environment-gated seeding logic
- [x] Task 7: Remove unused SwiftData `@Query` scaffolding
- [x] Task 8: Create `LibraryViewUITests.swift` with 2 test cases
- [x] Task 9: Update dev-log with implementation details
- [x] Task 10: Run full regression -- all tests passing (Exit Status: 0)
- [x] Empty state: `ContentUnavailableView` with `.accessibilityIdentifier("Library.EmptyState")`
- [x] Loading state: `ProgressView` with `.accessibilityIdentifier("Loading View")`
- [x] Heading: `Text("Heading Library")` with `.accessibilityAddTraits(.isHeader)`
- [x] Podcast cards: `.accessibilityIdentifier("Podcast-\(podcast.id)")` + `.accessibilityLabel` + `.accessibilityHint`
- [x] All interactive elements use `.buttonStyle(.plain)` with `.accessibilityAddTraits(.isButton)`
- [x] Given no subscriptions exist, Library tab shows "No Podcasts Yet" empty state
- [x] Given a podcast was added via Discover, Library tab shows it on next tab visit
- [x] Given app is force-quit and relaunched, previously added podcasts persist in Library
- [x] Given episode is tapped from Library, audio plays via PlaybackEngine (existing flow preserved)
- [x] `EpisodeListViewWrapper.createSamplePodcast()` remains unchanged

## Context
- Pipeline: autonomous
- Branch: feat/-27-1-9-wire-library-view-to-live-podcas-426
- Issue: #426
- Generated: 2026-03-07T20:21:58Z"
iteration: 0
max_iterations: 20
status: running
test_cmd: "bash ./scripts/run-xcode-tests.sh"
model: sonnet
agents: 1
started_at: 2026-03-07T21:58:34Z
last_iteration_at: 2026-03-07T21:58:34Z
consecutive_failures: 0
total_commits: 0
audit_enabled: true
audit_agent_enabled: true
quality_gates_enabled: true
dod_file: "/Volumes/zHardDrive/code/zpod/.claude/pipeline-artifacts/dod.md"
auto_extend: true
extension_count: 0
max_extensions: 3
---

## Log


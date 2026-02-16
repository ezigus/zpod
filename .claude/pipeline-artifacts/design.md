Now I have a thorough picture. Let me produce the ADR.

---

`★ Insight ─────────────────────────────────────`
**Why this ADR matters:** The plan touches four distinct subsystems — CoreModels (enum extension), LibraryFeature (swipe dispatch chain), PlaybackEngine (error handler + player), and the test layers (UI/Integration). The biggest architectural risk isn't any one change — it's the cross-module coordination. The `SwipeActionType` enum is `CaseIterable`, so adding a case changes the exhaustive set for every `switch` in the codebase. And the `SwipeActionHandler.performSwipeAction` requires a new callback slot in `SwipeActionCallbacks`, which flows into every ViewModel that wires callbacks. The ADR below makes these transitive impacts explicit.
`─────────────────────────────────────────────────`

---

# Design: [Issue 28.1.13] Final Acceptance Criteria Completion for Offline & Streaming

## Context

Issue 28.1 (Offline and Streaming Playback Infrastructure) is functionally complete — downloads work end-to-end, `EnhancedEpisodePlayer` falls back from local file to streaming URL, `StreamingErrorHandler` implements exponential backoff (2s / 5s / 10s matching spec), and 15 streaming + 8 offline UI tests pass. However, a static analysis audit identified six acceptance-criteria gaps:

**Offline gaps:**
1. No **download cancellation** swipe action exists — only pause/resume. The `cancelEpisodeDownload(_:)` ViewModel method exists (`EpisodeListViewModel+DownloadManagement.swift:115`) but has no UI surface.
2. **Fallback-to-streaming** tested only at data-model level (`OfflinePlaybackIntegrationTests`) — no test exercises the actual `EnhancedEpisodePlayer.localFileProvider` → `audioURL` fallback path.
3. Download resume after network loss tested as manual pause/resume, not network-triggered (deferred — outside current scope).

**Streaming gaps:**
4. Doc comment in `StreamingErrorHandler.swift:48-51` says "5s, 15s, 60s" but code is `[2.0, 5.0, 10.0]` — a stale comment, not a code bug.
5. No integration test for retry backoff **timing assertions** (delays requested are 2s, 5s, 10s) or **state machine transitions** (3 retries → `.failed`).
6. No integration test for **non-retryable error short-circuit** (e.g., 404 → immediate `.failed` via `isRetryableError`).

**Constraints:**
- Swift 6.1.2 strict concurrency. `SwipeActionType` is `CaseIterable` + `Sendable`.
- `SwipeActionHandler.performSwipeAction` uses exhaustive `switch` — adding a case is a compile error until all switches are updated.
- `SwipeActionCallbacks` struct must gain a `cancelDownload` field — every call site that constructs callbacks must be updated.
- Integration tests use `@testable import` and run in the `IntegrationTests/` target.
- UI tests use seed-first patterns (`SwipeConfigurationSeeding`, `DownloadStateSeeding`) — no real downloads in CI.

## Decision

### 1. Download Cancellation: Extend the existing swipe action dispatch chain

Add `case cancelDownload` to `SwipeActionType` in CoreModels. This is the canonical extension point — the enum already has `.deleteDownload` (which removes a *completed* download). `.cancelDownload` semantically differs: it aborts an *in-progress* download and deletes partial data.

**Data flow:**
```
User swipes → EpisodeListView.swipeButton(for: .cancelDownload, episode:)
  → viewModel.performSwipeAction(.cancelDownload, for: episode)
    → SwipeActionHandler.performSwipeAction switch
      → callbacks.cancelDownload(episode)
        → viewModel.cancelEpisodeDownload(episode)  [already exists at line 115]
          → downloadManager.cancelDownload(episode.id)
          → episode.withDownloadStatus(.notDownloaded)
          → NotificationCenter.post(.downloadDidCancel)
```

**Visibility rule:** `.cancelDownload` only appears when `episode.downloadStatus == .downloading || .paused`. This mirrors how `.deleteDownload` only appears for completed downloads.

**Why not reuse `.deleteDownload`:** Semantic clarity. `.deleteDownload` removes a completed local file; `.cancelDownload` aborts an in-progress transfer and cleans up partial data. They call different ViewModel methods and have different preconditions.

### 2. Fallback-to-Streaming: Test at the `EnhancedEpisodePlayer` level

The current `OfflinePlaybackIntegrationTests` only assert data-model properties (`episode.audioURL != nil`). The plan adds tests that instantiate `EnhancedEpisodePlayer` with a mock `localFileProvider` and verify:
- When `localFileProvider` returns `nil` → player uses `episode.audioURL` (the streaming path)
- When `localFileProvider` returns a file URL → player uses local file

This tests the actual branch at `EnhancedEpisodePlayer.swift:239-252`, not just the data model contract. Use `isDebugAudio` NSLog output or mock `AVPlayerPlaybackEngine` to capture which URL was selected.

### 3. Streaming Edge Cases: New integration test file with `InstantDelayProvider`

Create `IntegrationTests/StreamingEdgeCaseIntegrationTests.swift` with three focused tests:

- **Retry backoff timing:** Call `handleError` 3 times, assert `InstantDelayProvider.totalSecondsRequested == 17.0` (2+5+10), and final state is `.retrying(attempt: 3)`. Call a 4th time, assert `.failed`.
- **Non-retryable short-circuit:** Create a 404-style `NSError`, assert `isRetryableError` returns `false`. Verify that when the caller skips `handleError` for non-retryable errors, no state transition occurs.
- **Position preservation:** This is a contract assertion — `handleError` doesn't touch playback position; position management is the caller's responsibility. Test by verifying handler state doesn't include position fields.

### 4. Doc comment fix: Trivial alignment

Update `StreamingErrorHandler.swift` lines 48-51 from "5s, 15s, 60s" to "2s, 5s, 10s" to match the actual `retryDelays` array at line 75.

## Alternatives Considered

1. **Reuse `.deleteDownload` for cancel semantics** — Pros: No new enum case, fewer switch updates. / Cons: Conflates two distinct operations (abort in-progress vs. remove completed), confuses the visibility predicate, and the ViewModel already has separate methods (`cancelEpisodeDownload` vs. `deleteDownloadForEpisode`). Rejected for semantic clarity.

2. **Add cancel as a contextual button in EpisodeRowView instead of a swipe action** — Pros: No `SwipeActionType` enum change. / Cons: Breaks the established pattern where all episode actions are swipe-dispatched, inconsistent UX, and the swipe configuration system already supports per-preset action sets. Rejected for consistency.

3. **Test fallback-to-streaming only via UI tests** — Pros: Tests the full stack. / Cons: UI tests are slow, depend on simulator, and can't isolate the `localFileProvider` decision branch. The integration test directly exercises `EnhancedEpisodePlayer` with a controlled `localFileProvider` closure, giving deterministic coverage. Rejected the UI-only approach; integration test is sufficient.

4. **Put streaming edge-case tests in existing `StreamingErrorHandlerTests.swift`** — Pros: No new file. / Cons: Those are package-level unit tests in `PlaybackEngineTests`; the edge-case tests are cross-module integration tests that belong in `IntegrationTests/` to match the project's test taxonomy. Rejected for organizational consistency.

## Implementation Plan

### Files to create
- `IntegrationTests/StreamingEdgeCaseIntegrationTests.swift` — 3 new tests for retry backoff, non-retryable error, position preservation

### Files to modify
- `Packages/CoreModels/Sources/CoreModels/SwipeActionSettings.swift` — Add `case cancelDownload` with `displayName`, `systemIcon` (`xmark.circle.fill`), `colorTint` (`.red`), and `isDestructive: true`
- `Packages/LibraryFeature/Sources/LibraryFeature/SwipeActionHandler.swift` — Add `cancelDownload` callback to `SwipeActionCallbacks`, add `case .cancelDownload` to `performSwipeAction` switch
- `Packages/LibraryFeature/Sources/LibraryFeature/EpisodeListView.swift` — Wire `.cancelDownload` visibility predicate (downloading/paused only) and callback to `viewModel.cancelEpisodeDownload`
- `Packages/PlaybackEngine/Sources/PlaybackEngine/StreamingErrorHandler.swift` — Fix doc comment lines 48-51
- `IntegrationTests/OfflinePlaybackIntegrationTests.swift` — Add 2 behavioral fallback tests using `EnhancedEpisodePlayer` with mock `localFileProvider`
- `zpodUITests/DownloadFlowUITests.swift` — Add `testCancelDownloadResetsState()` UI test
- `zpodUITests/TestSupport/SwipeConfigurationSeeding.swift` — Add `cancelDownloadFocused` preset
- `Issues/28.1.13-final-acceptance-criteria-completion.md` — Update completion status
- `dev-log/28.1.13-implementation-plan.md` — Mark tasks complete

### Dependencies
- No new external dependencies
- Uses existing `InstantDelayProvider` from `PlaybackEngine/Tests/TestSupport`
- Uses existing `InMemoryPodcastManager` from `TestSupport`

### Risk areas
1. **`SwipeActionType.CaseIterable` exhaustiveness** — Adding `.cancelDownload` will cause compile errors in every exhaustive `switch` over `SwipeActionType`. Must audit all consumers: `SwipeActionHandler.performSwipeAction`, `SwipeActionView` button builder, any test factories. The compiler enforces this, so the risk is catching all sites before the build succeeds.
2. **`SwipeActionCallbacks` call-site updates** — Every place that constructs a `SwipeActionCallbacks` must provide the new `cancelDownload` parameter. The default value (`{ _ in }`) in the `init` mitigates this — existing call sites compile without changes, but the callback would be a no-op until explicitly wired.
3. **`EnhancedEpisodePlayer` integration test isolation** — Testing the `localFileProvider` branch requires constructing a player with a mock `AVPlayerPlaybackEngine` or using the ticker-based path. The `isDebugAudio` logging can serve as an observable side-effect, but a cleaner approach is injecting a spy `audioEngine`.
4. **UI test determinism** — The cancel UI test seeds a downloading episode via `DownloadStateSeeding`, then swipes. If the seeded state doesn't render a progress indicator before the swipe, the test may flake. Mitigation: use `waitForExistence` on the download indicator before swiping.

## Validation Criteria

- [ ] `SwipeActionType.cancelDownload` exists with correct `displayName` ("Cancel Download"), `systemIcon` (`xmark.circle.fill`), `colorTint` (`.red`), and `isDestructive == true`
- [ ] `SwipeActionHandler.performSwipeAction(.cancelDownload, ...)` dispatches to `callbacks.cancelDownload(episode)`
- [ ] `.cancelDownload` swipe button is visible only when `episode.downloadStatus` is `.downloading` or `.paused`
- [ ] `testCancelDownloadResetsState()` UI test: seeds downloading episode → swipes cancel → asserts download status resets to `.notDownloaded`
- [ ] `testLocalFileProviderReturnsNil_FallsBackToStreamingURL()` integration test: `EnhancedEpisodePlayer` with `localFileProvider` returning `nil` uses `episode.audioURL`
- [ ] `testLocalFileProviderReturnsFile_UsesLocalPath()` integration test: player uses local file URL when provider returns one
- [ ] `testRetryBackoffDelaysMatchSpec()` integration test: 3 retries request cumulative 17.0s via `InstantDelayProvider`, 4th call returns `false` with `.failed` state
- [ ] `testNonRetryableErrorSkipsRetry()` integration test: `isRetryableError` returns `false` for 404-style error
- [ ] `StreamingErrorHandler.swift` doc comment reads "2s, 5s, 10s" matching the `retryDelays` array
- [ ] Full regression passes: `./scripts/run-xcode-tests.sh` with zero failures
- [ ] Zero `XCTSkip` in `DownloadFlowUITests` and `OfflinePlaybackUITests`

---

`★ Insight ─────────────────────────────────────`
1. **Enum extension ripple effects** — Adding a case to a `CaseIterable` enum in a shared module (CoreModels) triggers compile errors across every downstream module that switches over it. This is actually a *safety feature*: the compiler guarantees you can't forget to handle the new case. The implementation plan accounts for this by identifying all switch sites upfront.
2. **Testing at the right layer** — The plan strategically places tests at two levels: *integration tests* for the `EnhancedEpisodePlayer` fallback logic and `StreamingErrorHandler` state machine (fast, deterministic, no simulator), and *UI tests* only for the cancel action UX (needs simulator but validates end-to-end). This avoids the anti-pattern of testing everything through slow UI tests.
3. **`InstantDelayProvider` as a testing seam** — The `DelayProvider` protocol is an excellent example of the "humble object" pattern. Production code uses real `Task.sleep`; tests inject `InstantDelayProvider` which records requested delays without waiting. This lets the streaming edge-case tests assert *what delays would have been* without actually sleeping 17 seconds.
`─────────────────────────────────────────────────`

---
goal: "[Issue 28.1.13] Final Acceptance Criteria Completion for Offline & Streaming

## Plan Summary
The implementation plan is written to `dev-log/28.1.13-implementation-plan.md` and covers 13 discrete tasks across 4 priority levels:

**Summary of the plan:**

1. **Quick fix** — Update stale doc comment in `StreamingErrorHandler` (the "spec mismatch" was a phantom — code already matches spec)

2. **Download Cancellation** (biggest new work) — Add `.cancelDownload` swipe action type, wire it to the existing `cancelEpisodeDownload` ViewModel method, add UI test that seeds a downloading episode and verifies cancel resets state

3. **Fallback-to-Streaming** — Add behavioral integration tests that verify `EnhancedEpisodePlayer` actually falls back to `audioURL` when `localFileProvider` returns nil (current tests only check data model)

4. **Streaming Edge Cases** — Add integration tests for retry backoff state machine (3 retries → failed), non-retryable error short-circuit (404), and position preservation through retries

5. **Full regression** and issue/dev-log updates
[... full plan in .claude/pipeline-artifacts/plan.md]

## Key Design Decisions
# Design: [Issue 28.1.13] Final Acceptance Criteria Completion for Offline & Streaming
## Context
## Decision
### 1. Download Cancellation: Extend the existing swipe action dispatch chain
### 2. Fallback-to-Streaming: Test at the `EnhancedEpisodePlayer` level
### 3. Streaming Edge Cases: New integration test file with `InstantDelayProvider`
### 4. Doc comment fix: Trivial alignment
## Alternatives Considered
## Implementation Plan
### Files to create
[... full design in .claude/pipeline-artifacts/design.md]

Historical context (lessons from previous pipelines):
{"error":"intelligence_disabled","results":[]}"
iteration: 3
max_iterations: 20
status: running
test_cmd: "npm test"
model: opus
agents: 1
started_at: 2026-02-16T17:32:29Z
last_iteration_at: 2026-02-16T17:32:29Z
consecutive_failures: 0
total_commits: 3
audit_enabled: true
audit_agent_enabled: true
quality_gates_enabled: true
dod_file: ""
auto_extend: true
extension_count: 0
max_extensions: 3
---

## Log
### Iteration 1 (2026-02-16T17:01:02Z)
- 87 integration tests
- 814 package tests
- 59 AppSmoke tests

### Iteration 2 (2026-02-16T17:08:35Z)
| Integration | Pass | 87/87 |
| PlaybackEngine | Pass | 49/49 |
| Issue docs updated | Done | Marked COMPLETE with delivery summary |

### Iteration 3 (2026-02-16T17:32:29Z)
4. **All new functions tested?** YES — 87/87 integration, 49/49 PlaybackEngine, 59/59 AppSmoke
5. **Would a code reviewer approve?** YES — issue file documents comprehensive completion, dev-log updated, all 11 tasks
6. **Code clean and following conventions?** YES — syntax check passes on all 279 files


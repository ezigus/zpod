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
iteration: 1
max_iterations: 20
status: running
test_cmd: "npm test"
model: opus
agents: 1
started_at: 2026-02-16T17:01:02Z
last_iteration_at: 2026-02-16T17:01:02Z
consecutive_failures: 0
total_commits: 1
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


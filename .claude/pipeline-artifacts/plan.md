The implementation plan is written to `dev-log/28.1.13-implementation-plan.md` and covers 13 discrete tasks across 4 priority levels:

**Summary of the plan:**

1. **Quick fix** — Update stale doc comment in `StreamingErrorHandler` (the "spec mismatch" was a phantom — code already matches spec)

2. **Download Cancellation** (biggest new work) — Add `.cancelDownload` swipe action type, wire it to the existing `cancelEpisodeDownload` ViewModel method, add UI test that seeds a downloading episode and verifies cancel resets state

3. **Fallback-to-Streaming** — Add behavioral integration tests that verify `EnhancedEpisodePlayer` actually falls back to `audioURL` when `localFileProvider` returns nil (current tests only check data model)

4. **Streaming Edge Cases** — Add integration tests for retry backoff state machine (3 retries → failed), non-retryable error short-circuit (404), and position preservation through retries

5. **Full regression** and issue/dev-log updates

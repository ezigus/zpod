# Repo-Specific Claude Additions

Add repo-local Claude notes here. This file is preserved across installs.

## XCUITest Quiescence / "Waiting for App to Idle"

**Problem**: XCUITest hangs on "Wait for us.zig.zpod to idle" when timers or
Combine subscriptions fire continuously on the main thread.

**Root cause chain**: `DispatchSourceTimer(.main)` → `Task { @MainActor }` →
`CurrentValueSubject.send()` → `.receive(on: RunLoop.main)` → SwiftUI re-render.
Each link prevents the main run loop from draining between ticks.

**Fix pattern**: When a `@MainActor` class receives callbacks from a
`DispatchQueue.main` timer, use `MainActor.assumeIsolated { }` instead of
`Task { @MainActor in }`. This executes synchronously without creating async
task submissions, allowing XCUITest's quiescence detector to see idle gaps
between timer firings.

**Do NOT**: Swizzle `_waitForQuiescence*` (breaks event synthesis), use
`sleep`/`timeout` to wait it out, or add `UITEST_DISABLE_*` flags that change
playback behavior vs production.

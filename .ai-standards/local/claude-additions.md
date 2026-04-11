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

## Compound Quality Audit — Full File Rule

**Problem**: During the `compound_quality` pipeline stage, audit agents receive a git
diff as context. Diffs only show changed hunks; unchanged lines (such as import
statements at the top of a file) are absent from the diff window. An agent that
infers what is present in a file solely from the diff will hallucinate findings
about content it never saw.

**Rule**: When the compound audit stage (or any audit/review agent) identifies a
potential issue in a file, it MUST read the full current file content using the Read
tool before reporting the finding. The diff is a reference for *what changed*, not
a complete view of the file.

**Specifically**:
- A claim that something is "missing" (an import, a method, a guard) MUST be
  verified by reading the current file — not inferred from the diff's context window.
- If a build succeeds with exit 0, claims about missing imports in files that were
  compiled are almost certainly false. Cross-check against build success before
  escalating to critical severity.
- Never fabricate a list of "present" imports or declarations based on what appears
  in a diff hunk. Only report what you have actually read from the file.

# Lint Cleanup

## Intent (2025-09-28 19:32 EDT)
- Address recurring SwiftLint violations reported by `./scripts/run-xcode-tests.sh -l`.
- Focus on bulk patterns: redundant string enum raw values, identifier aliases named `or`, and oversized type bodies.
- Apply localized rule suppressions only where restructuring is out of current scope (large view models/tests).

```mermaid
flowchart TD
    Lint[Run SwiftLint] --> Patterns[Cluster violations]
    Patterns --> BulkFixes[Bulk fix shared issues]
    BulkFixes --> Targeted[Handle one-off warnings]
    Targeted --> Verify[Re-run lint suite]
```

## Plan (2025-09-28 19:32 EDT)
1. Remove explicit raw string values that duplicate case names across CoreModels/Persistence modules.
2. Preserve domain-specific `or` enum cases by adding scoped SwiftLint disables with justification.
3. Split long literals (EpisodeDetailView) and simplify optional checks (SettingsDomain) to satisfy rules.
4. Add documented per-type lint suppressions for oversized legacy actors/classes pending refactors.
5. Re-run lint suite to confirm a clean report and capture the new log.

## Progress (2025-09-28 19:45 EDT)
- Filed Issue 02.2 with sub-issues 02.2.1 through 02.2.4 to track refactors for oversized types flagged during lint cleanup.

## Progress (2025-09-28 19:48 EDT)
- Published matching GitHub issues #68 through #72 to keep numbering aligned with local files 02.2/02.2.1-02.2.4.

## Progress (2025-09-28 20:13 EDT)
- Updated `scripts/run-xcode-tests.sh` to capture per-section summaries (syntax/build/test/lint/testplan) based on requested flags, emitting a final summary block with the relevant log paths.

## Intent (2025-12-20 14:42 EST)
- Clear the latest SwiftLint warnings in UI tests and the player episode detail view.
- Prefer modular extraction over suppressions to keep refactors traceable.

```mermaid
flowchart TD
    Lint[Run SwiftLint] --> Targets[Identify warning locations]
    Targets --> Extract[Extract helpers/types]
    Extract --> Verify[Re-run lint]
```

## Plan (2025-12-20 14:42 EST)
1. Split oversized UI test classes into extensions or helper types.
2. Flatten nested types in swipe configuration test support.
3. Rename short enum cases to satisfy identifier length.
4. Refactor EpisodeDetailView to smaller subviews.

## Progress (2025-12-20 14:47 EST)
- Split CoreUINavigationTests/PlaybackUITests into sectioned extensions to drop type body length warnings.
- Flattened swipe settings persistence structs and renamed scroll direction case to satisfy nesting/identifier rules.
- Moved EpisodeDetailView helpers into an extension and re-linted cleanly.

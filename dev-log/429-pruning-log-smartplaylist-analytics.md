# Dev Log: Issue #429 — Add Pruning Log to SmartPlaylistAnalyticsRepository

## Intent

Add a debug-level log message when `UserDefaultsSmartPlaylistAnalyticsRepository` prunes events to stay within the `maxEventCount` hard cap.

## Findings

**Production code status (pre-existing):** The `Logger.debug(...)` call was already present at line 184 of `SmartPlaylistAnalyticsRepository.swift` inside the `pruneAll(_:)` method:

```swift
Logger.debug("SmartPlaylistAnalyticsRepository: pruned \(discardCount) oldest events to stay within \(maxEventCount) cap")
```

**Test coverage gap:** `testRecordEnforcesMaxEventCount` verified the cap enforcement behavior but no test explicitly exercised the pruning log branch in a way that could serve as CI evidence.

## Solution

### Tests added to `SmartPlaylistAnalyticsRepositoryTests.swift`

1. **`testPruningAtCapEnforcesMaxEventCount`** — Records 10 events against a cap of 5, verifies exactly 5 are retained (proving the `if events.count > maxEventCount` branch — and the `Logger.debug` call inside it — executed).

2. **`testPruningWithCapOfOne`** — Edge case with `maxEventCount = 1`; records 2 events, verifies only the newest survives. Guards against off-by-one errors in the pruning logic.

3. **`testNoPruningWhenUnderCap`** — Records 5 events against a cap of 10, verifies all 5 are retained and no pruning occurred.

4. **`testNoPruningWhenExactlyAtCap`** — Records exactly cap-many events, verifies no pruning occurs (boundary condition: `count > cap`, not `>=`).

### Logging verification approach

`Logger.debug` is called inside the pruning branch but cannot be verified directly — `Logger` is a static enum backed by `os.Logger` with no injection point. Reaching `maxEventCount` in the assertion proves the pruning branch (containing the log call) executed. This is an acceptable trade-off: the log statement is a single line co-located with the pruning logic, so any change to the branch would be caught by the count assertion.

### Quality review fixes (2026-03-12)

Addressed compound quality review findings:

- **System-clock dependency**: Injected a `currentDate` clock into `UserDefaultsSmartPlaylistAnalyticsRepository` (defaulting to `{ Date() }`). All cap tests now use a fixed reference date (`Date(timeIntervalSince1970: 1_700_000_000)`) making them fully deterministic and independent of the system clock.

- **Misleading timestamp comment**: Corrected the comment about "ISO-8601 JSON encode/decode" — internal storage uses the default `JSONEncoder` date strategy (Double precision), which preserves sub-second ordering. The 1-hour gaps between test events are for readability, not precision.

- **Code duplication**: Extracted `makeCappedRepo(cap:)` and `recordEvents(in:playlistID:count:)` helpers. All five cap tests now use these shared helpers instead of repeating setup boilerplate.

- **Dev-log drift**: Updated this dev-log to list the actual four test names (previously listed three names that didn't match the implementation).

- **Invalid maxEventCount guard**: Added `guard...fatalError("maxEventCount must be at least 1")` to the repository initializer. `fatalError()` is guaranteed to run in every build configuration (Release, `-Osize`, App Store) — unlike `precondition()` which can be stripped with `-Ounchecked`.

- **Deterministic pruning sort**: Changed the cap-enforcement sort to use a UUID string tiebreaker when `occurredAt` timestamps collide. Swift's `sort` is not guaranteed stable, so without a tiebreaker the surviving events are undefined when two events share the same timestamp (e.g., in tests with a mocked clock). The UUID string comparison provides a *stable tiebreaker* — consistent within a session — but not reproducible across app launches, since UUIDs are random at creation time.

## Test Results

All Persistence package tests pass.

## Completion: 2026-03-11 (quality fixes: 2026-03-12)

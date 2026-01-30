# Test Flakiness Investigation & Remediation Plan

**Created**: 2026-01-18  
**Status**: Investigation Phase  
**Related Issues**: #02.7, #12.7, #27.1.2  
**Priority**: Critical

---

## 2026-01-30 — Mini player playback state race (intent)

- **Observed failure**: `PlaybackPositionAVPlayerTests.testMiniPlayerReflectsPlaybackState` timed out at 10:02 ET with message "Mini player should show pause button when AVPlayer is playing".
- **Repro**: Fails intermittently in suite; passes 4/4 when run alone.
- **Hypothesis**: `startPlaybackFromPlayerTab()` returns after the mini player becomes visible but before AVPlayer transitions to `.playing`, so the Pause button identifier isn't present when the test asserts.
- **Planned fix**: In `PlaybackPositionTestSupport.startPlaybackFromPlayerTab()`, keep the mini-player wait but add a second wait for `"Mini Player Pause"` using `adaptiveShortTimeout`, logging diagnostics if `"Mini Player Play"` remains visible; return false on failure.
- **Success criteria**: Target test passes 5/5 consecutive runs; full `PlaybackPositionAVPlayerTests` suite remains green.

---

## 2026-01-30 — Implementation & verification

- Updated `startPlaybackFromPlayerTab()` to block until the `"Mini Player Pause"` button appears after the mini player becomes visible, logging whether `"Mini Player Play"` is still present before failing.
- Rationale: align helper semantics with "playback started" and eliminate the race where visibility precedes `state.isPlaying == true`.
- Verification: `./scripts/run-xcode-tests.sh -t zpodUITests/PlaybackPositionAVPlayerTests/testMiniPlayerReflectsPlaybackState` passed (16:42–16:44 ET). Artifacts: `TestResults/TestResults_20260130_164250_test_zpodUITests-PlaybackPositionAVPlayerTests-testMiniPlayerReflectsPlaybackState.xcresult` and `.log`.
- Next: run the full `PlaybackPositionAVPlayerTests` suite to confirm no regressions.

---

## 2026-01-18 — Execution plan (quarantine deprecated suite + harness guardrails)

**Intent (before code)**: stop system-level crashes by quarantining the deprecated playback suite, prove coverage lives in the replacement suites, and add guardrails so deprecated UI tests cannot silently re-enter the plan.

```mermaid
flowchart TD
  A[Deprecated suite discovered] --> B[Mark suite skipped at source (XCTSkip)]
  B --> C[Exclude suite from xctestplan]
  C --> D[Guardrail: warn on deprecated suites in test harness]
  D --> E[Document coverage mapping & rationale]
  E --> F[Run targeted validation / lint]
```

**Steps to implement now**
- Quarantine `PlaybackPositionUITests` via in-test `XCTSkip` and `xctestplan` skip list; keep file for short-term traceability.
- Update `TestSummary.md` to state coverage is provided by `PlaybackPositionTickerTests` + `PlaybackPositionAVPlayerTests`.
- Add a harness-side warning to surface deprecated suites during `run-xcode-tests.sh` runs.
- Keep future phases (base class, simulator hygiene) in backlog but unblock runs immediately.

---

## Executive Summary

### Current State (2026-01-18)

**Critical Findings**:
- **System-level failures** increasing: 59 "Early unexpected exit" crashes in past 7 days (1,039 test runs)
- **Failure rate**: ~5.7% catastrophic failures (test runner crashes before tests execute)
- **Most affected test**: `PlaybackPositionUITests` (deprecated but still running)
- **Primary symptom**: `missing bundleID for main bundle` → test runner crash
- **Secondary issue**: ~20-25% test-execution failures (element discovery, timing, state pollution)

**Baseline Metrics**:
- Total UI test code: ~25K lines across 19 test classes
- 765 test log files in past 7 days (high CI churn)
- 287 `@MainActor` annotations in test code
- Recent CI runs: ~93% failure rate (up from historical ~75%)

**Key Observation**: Flakiness **increasing over time** despite past remediation efforts (Issues #02.7, #12.7). This suggests architectural debt accumulating faster than fixes.

---

## Root Cause Analysis

### Category 1: System-Level Crashes (NEW - ~60% of recent failures)

**Symptom**: "Early unexpected exit, operation never finished bootstrapping"

**Technical Details**:
```
zpodUITests-Runner (68096) encountered an error 
(Early unexpected exit, operation never finished bootstrapping - 
 no restart will be attempted. 
 (Underlying Error: The test runner crashed before establishing connection: 
  zpodUITests-Runner at <external symbol>))

failure in void __BKSHIDEvent__BUNDLE_IDENTIFIER_FOR_CURRENT_PROCESS_IS_NIL__
missing bundleID for main bundle
```

**Root Causes**:
1. **Test runner initialization failure**: XCTest infrastructure can't establish connection to app
2. **Bundle configuration issues**: Missing or invalid bundle identifiers during test setup
3. **Simulator state corruption**: Repeated test runs without proper cleanup
4. **Timing race**: Test runner starts before app is fully initialized
5. **Resource exhaustion**: CI runners low on memory/CPU during parallel execution

**Evidence**:
- Only 1 unique test class affected recently (`PlaybackPositionUITests`)
- File marked DEPRECATED but still executing in CI
- Error occurs **before any test code runs** (infrastructure issue, not test logic)

**Impact**: Wastes ~3-5 minutes per failure before tests even start

---

### Category 2: Element Discovery & Timing (~25% of failures)

**Symptoms**:
- Elements not found despite `waitForExistence(timeout:)`
- Timeouts on SwiftUI List lazy loading
- ScrollView materialization race conditions

**Root Causes**:
1. **SwiftUI lazy unmaterialization**: Elements scroll out of view and disappear from accessibility tree
   - Documented in `preventing-flakiness.md` but not systematically enforced
   - Tests assume pre-materialization keeps elements accessible (it doesn't)
2. **Fixed timeouts insufficient for CI**: `adaptiveTimeout` not scaling properly under load
3. **Missing `ensureVisibleInSheet()` calls**: Tests interact with off-screen elements
4. **Animation completion races**: Taps during SwiftUI transitions

**Evidence**:
- 10 flaky tests identified in flakiness dashboard (all UI-related)
- SwipePresetSelection failures: 45.5% of test-execution failures
- Pattern: Failures cluster around sheet-based configuration UI

**Existing Mitigations** (partial):
- `UITestStableWaitHelpers.swift`: Frame stability primitives
- `UITestRetryHelpers.swift`: Diagnostic helpers
- `preventing-flakiness.md`: Best practices documentation

**Gap**: Infrastructure exists but **not consistently applied** across test suite

---

### Category 3: Test Architecture & Complexity (~10% of failures)

**Symptoms**:
- Oversized test scenarios (600+ line test files)
- Heavy reliance on `@MainActor` isolation (287 annotations)
- Inconsistent app launch patterns across test classes
- State pollution between tests

**Root Causes**:
1. **Duplicate test infrastructure**: `PlaybackPositionUITests` deprecated but running alongside replacements
2. **Inconsistent setup/teardown**: Each test class implements own `launchApp()` pattern
3. **Shared test state**: `nonisolated(unsafe) var app: XCUIApplication!` allows cross-test contamination
4. **Missing isolation**: Tests don't always clear UserDefaults/Keychain between runs

**Evidence**:
- `PlaybackPositionUITests.swift` (620 lines) marked deprecated Jan 8, still running Jan 17
- 19 test classes, each with custom setup patterns
- `UITestEnvironmentalIsolation.swift` exists but optional usage

**Technical Debt**:
- Test code complexity growing faster than app code (25K lines for ~100 test scenarios)
- Helpers accumulated organically without architectural review
- No enforcement of test isolation patterns

---

### Category 4: CI Infrastructure & Parallelization (~5% of failures)

**Symptoms**:
- Simulator provisioning conflicts
- Resource contention during parallel execution
- Inconsistent simulator state between runs

**Root Causes**:
1. **Parallel simulator creation**: Hash-based delays insufficient for 5+ concurrent jobs
2. **Shared DerivedData contamination**: Isolation via `ZPOD_DERIVED_DATA_PATH` incomplete
3. **Test runner memory pressure**: No limits on concurrent test execution
4. **Simulator cleanup gaps**: Boot state persists between CI jobs

**Evidence**:
- CI workflow provisions unique simulator per suite (`zpod-<run_id>-<suite>`)
- Retry logic (3 attempts, exponential backoff) exists but still seeing failures
- Recent changes: Issue #12.7.1 added UI retry, may have introduced new races

**Recent Changes** (potential regression sources):
- `a480f44`: Siri snapshot integration (Jan 17)
- `c8a68b1`: Architecture follow-up issues (Jan 17)
- `e3ccdad`: UI retry capped to single pass (Jan 17)

---

## Industry Best Practices Review

### Current Gaps vs. Best Practices

| Practice | Industry Standard | zpod Current State | Gap Severity |
|----------|-------------------|-------------------|--------------|
| **Test Isolation** | Each test resets all state | Optional cleanup helpers | 🔴 High |
| **Deterministic Waits** | Predicate-based, no fixed timeouts | Mixed (some `Thread.sleep` usage) | 🟡 Medium |
| **Single Responsibility** | 1 test = 1 scenario | Some 100+ line acceptance tests | 🟡 Medium |
| **Page Object Pattern** | Centralized element access | Ad-hoc element queries | 🔴 High |
| **Retry Strategy** | Infrastructure retries, not test retries | Recent addition, may be overused | 🟡 Medium |
| **Deprecated Test Removal** | Immediate upon replacement | Tests run weeks after deprecation | 🔴 High |
| **CI Resource Limits** | CPU/memory limits per test | No explicit limits | 🟡 Medium |
| **Flakiness Monitoring** | Automated tracking, alerting | Manual log analysis | 🔴 High |

### Recommended Patterns (Industry Leading)

1. **Test Isolation via Protocol Extensions**
   ```swift
   protocol IsolatedUITest {
       func resetAppState()
   }
   extension IsolatedUITest {
       func resetAppState() {
           clearUserDefaults()
           clearKeychain()
           resetSimulatorDefaults()
       }
   }
   // Enforce via XCTest subclass, not optional helpers
   ```

2. **Centralized Element Discovery**
   ```swift
   struct LibraryScreen {
       let app: XCUIApplication
       var podcastCard: XCUIElement {
           app.buttons.matching(identifier: "Podcast-swift-talk")
               .firstMatch
               .ensureVisible(in: "Podcast Cards Container")
       }
   }
   // Eliminates ad-hoc element queries scattered across tests
   ```

3. **Explicit Test Dependencies**
   ```swift
   func testAdvancedFeature() throws {
       try XCTSkipUnless(FeatureFlags.isEnabled(.advancedUI))
       try XCTSkipUnless(app.buttons["Prerequisite"].exists)
       // Clear failure reason, no wasted CI time
   }
   ```

4. **Flakiness Budgets**
   ```yaml
   test-targets:
     - name: zpodUITests
       flakiness-threshold: 2%
       action-on-exceed: fail-ci-and-notify
   ```

5. **Test Timing Budgets**
   ```swift
   // Per-test runtime limits
   func testQuickOperation() {
       measureWithBudget(5.seconds) {
           // Test code
       }
   }
   // CI fails if test exceeds budget (indicates infrastructure issue)
   ```

---

## Proposed Remediation Plan

### Phase 1: Stop the Bleeding (Week 1) - IMMEDIATE

**Goal**: Reduce system-level crashes by 80% within 48 hours

**Actions**:
1. ✅ **Quarantine deprecated `PlaybackPositionUITests.swift`**
   - Already replaced by `PlaybackPositionTickerTests` + `PlaybackPositionAVPlayerTests`
   - Keep file temporarily for traceability but skip by default (plan skip + XCTSkip unless explicitly enabled)
   - **Impact**: Eliminates primary source of "Early unexpected exit" crashes while maintaining rollback visibility

2. ✅ **Update `.xctestplan` to exclude deprecated file**
   - Remove from test discovery if not already excluded
   - Verify CI workflow not explicitly targeting this file

3. ✅ **Add pre-flight warning in harness for deprecated suites**
   ```bash
   # Warn if deprecated suites exist or are not skipped in xctestplan
   ./scripts/run-xcode-tests.sh  # emits warning when deprecated UI suites are present/not skipped
   ```

4. 🔧 **Implement test runner health check**
   ```swift
   override class func setUp() {
       super.setUp()
       // Fail fast if bundle configuration invalid
       guard Bundle.main.bundleIdentifier != nil else {
           fatalError("Bundle identifier missing - test runner misconfigured")
       }
   }
   ```

**Acceptance Criteria**:
- Zero "Early unexpected exit" failures in next 20 CI runs
- `PlaybackPositionUITests.swift` quarantined (skipped in plan + XCTSkip) unless explicitly enabled
- CI run failure rate drops below 10%

---

### Phase 2: Architectural Refactoring (Weeks 2-3)

**Goal**: Establish repeatable, maintainable test patterns

#### 2A: Test Isolation Protocol (Week 2)

**Problem**: Optional cleanup allows state pollution

**Solution**: Mandatory isolation via base class
```swift
/// Base class enforcing test isolation
class IsolatedUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try super.setUpWithError()
        resetEnvironment()
    }
    
    override func tearDownWithError() throws {
        resetEnvironment()
        try super.tearDownWithError()
    }
    
    private func resetEnvironment() {
        // ALWAYS executed, not optional
        clearUserDefaults()
        clearKeychain()
        terminateApp()
    }
}

// All test classes MUST inherit
final class ContentDiscoveryUITests: IsolatedUITestCase { ... }
```

**Migration**:
- Create `IsolatedUITestCase.swift`
- Update all 19 test classes to inherit
- Remove redundant cleanup code from individual tests
- Verify via CI that isolation prevents cross-test contamination

**Acceptance Criteria**:
- All test classes inherit `IsolatedUITestCase`
- Zero state pollution failures in 50 CI runs
- Test setup/teardown code reduced by 30%

---

#### 2B: Page Object Pattern (Week 2-3)

**Problem**: 287 ad-hoc element queries scattered across tests

**Solution**: Centralized screen representations
```swift
// zpodUITests/PageObjects/LibraryScreen.swift
struct LibraryScreen {
    let app: XCUIApplication
    
    // MARK: - Elements
    var container: XCUIElement {
        app.otherElements.matching(identifier: "Podcast Cards Container").firstMatch
    }
    
    func podcastCard(id: String) -> XCUIElement {
        container.buttons
            .matching(identifier: "Podcast-\(id)")
            .firstMatch
            .ensureVisible(in: container)  // Handles scrolling automatically
    }
    
    // MARK: - Actions
    func tapPodcast(_ id: String) {
        podcastCard(id: id).tap()
    }
    
    // MARK: - Assertions
    func assertLoaded(timeout: TimeInterval = 5) -> Bool {
        container.waitForExistence(timeout: timeout)
    }
}

// Usage in tests
func testNavigateToPodcast() {
    let library = LibraryScreen(app: app)
    XCTAssertTrue(library.assertLoaded())
    library.tapPodcast("swift-talk")
    // Clear, maintainable, no direct element queries
}
```

**Migration**:
1. Create `PageObjects/` directory structure
2. Extract screens: Library, EpisodeList, Player, Settings, SwipeConfiguration
3. Refactor 2-3 test classes per day (incremental)
4. Update `UITestHelpers.swift` to support page objects

**Acceptance Criteria**:
- Page objects for 5 primary screens implemented
- 50% of tests migrated to page object pattern
- Element query duplication reduced by 60%
- New tests MUST use page objects (enforced via code review)

---

#### 2C: Deterministic Wait Consolidation (Week 3)

**Problem**: Inconsistent wait patterns, some `Thread.sleep` usage

**Solution**: Single wait API, predicate-based only
```swift
extension XCUIElement {
    /// The ONLY wait method tests should use
    func waitUntil(
        _ condition: WaitCondition,
        timeout: TimeInterval = adaptiveTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        let predicate: NSPredicate
        switch condition {
        case .exists:
            predicate = NSPredicate(format: "exists == true")
        case .hittable:
            predicate = NSPredicate(format: "isHittable == true")
        case .stable(let window):
            return waitForStable(timeout: timeout, stabilityWindow: window)
        case .value(let expectedValue):
            predicate = NSPredicate(format: "value == %@", expectedValue)
        }
        
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        
        if result != .completed {
            diagnoseTimeout(condition: condition, file: file, line: line)
        }
        
        return result == .completed
    }
}

enum WaitCondition {
    case exists
    case hittable
    case stable(TimeInterval)
    case value(String)
}
```

**Migration**:
- Add `@available(*, deprecated)` to old wait helpers
- Add compiler warnings for `Thread.sleep` usage
- Refactor tests to use new unified API

**Acceptance Criteria**:
- Zero `Thread.sleep` calls in test code
- Single wait API used across all tests
- Wait timeout failures include full diagnostics

---

### Phase 3: Infrastructure Hardening (Week 4)

**Goal**: Prevent regressions, monitor flakiness proactively

#### 3A: Automated Flakiness Tracking

**Implementation**:
```yaml
# .github/workflows/flakiness-tracker.yml
name: Flakiness Monitor
on:
  schedule:
    - cron: '0 0 * * *'  # Daily
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - name: Analyze past 100 runs
        run: |
          python3 scripts/analyze-flakiness.py \
            --window 100 \
            --threshold 5% \
            --output flakiness-report.md
      
      - name: Comment on PR if threshold exceeded
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              body: '🚨 Flakiness threshold exceeded! See attached report.'
            })
```

**Script** (`scripts/analyze-flakiness.py`):
- Parse CI logs from GitHub Actions API
- Calculate per-test failure rates
- Generate Markdown report with trends
- Fail if any test exceeds 5% failure rate

---

#### 3B: Test Runtime Budgets

**Implementation**:
```swift
// zpodUITests/UITestHelpers.swift
func measureWithBudget<T>(
    _ budget: TimeInterval,
    file: StaticString = #file,
    line: UInt = #line,
    _ operation: () throws -> T
) rethrows -> T {
    let start = Date()
    defer {
        let elapsed = Date().timeIntervalSince(start)
        if elapsed > budget {
            XCTFail(
                "Test exceeded runtime budget: \(elapsed)s > \(budget)s. " +
                "This indicates infrastructure issues, not test failures.",
                file: file,
                line: line
            )
        }
    }
    return try operation()
}

// Usage
func testQuickOperation() {
    measureWithBudget(5.0) {
        // Test code that should complete in <5s
        // If it takes longer, infrastructure is degraded
    }
}
```

**Budgets per test type**:
- Navigation tests: 10s
- Playback tests: 30s
- Configuration tests: 15s

---

#### 3C: CI Resource Limits

**Implementation**:
```yaml
# .github/workflows/ci.yml (updated)
jobs:
  ui-tests:
    strategy:
      matrix:
        suite: [Navigation, Playback, Configuration]
      max-parallel: 3  # Down from 5 (reduce contention)
    steps:
      - name: Run tests with resource limits
        run: |
          # Limit test runner CPU/memory
          ulimit -v 4194304  # 4GB RAM max
          caffeinate -i ./scripts/run-xcode-tests.sh -t ${{ matrix.suite }}
        timeout-minutes: 20  # Kill if stuck
        env:
          ZPOD_TEST_TIMEOUT_SCALE: 1.5  # CI gets more time
```

**Additional hardening**:
- Add simulator health check before each test run
- Fail fast if simulator unresponsive
- Collect crash logs automatically

---

### Phase 4: Documentation & Training (Week 5)

**Goal**: Ensure team follows new patterns

**Deliverables**:
1. **Updated AGENTS.md section** on UI testing
   - Link to page object examples
   - Mandate `IsolatedUITestCase` inheritance
   - Explain wait API usage

2. **Test writing checklist** (`docs/testing/ui-test-checklist.md`)
   ```markdown
   - [ ] Inherits from `IsolatedUITestCase`
   - [ ] Uses page objects for element access
   - [ ] No `Thread.sleep` calls
   - [ ] Uses `waitUntil()` for synchronization
   - [ ] Has runtime budget defined
   - [ ] Verifies prerequisites with `XCTSkipUnless`
   - [ ] Single scenario per test method
   ```

3. **Migration guide** for existing tests
   - Step-by-step refactoring instructions
   - Before/after examples
   - Common pitfalls

4. **Flakiness runbook** (`docs/testing/flakiness-runbook.md`)
   - How to diagnose flaky test
   - When to use each wait helper
   - How to read accessibility tree dumps
   - When to file infrastructure vs. test bug

---

## Success Metrics & Monitoring

### Week-by-Week Targets

| Week | Metric | Target | Baseline |
|------|--------|--------|----------|
| 1 | System crash rate | <1% | 5.7% |
| 1 | CI run success rate | >90% | ~7% |
| 2 | Test isolation violations | 0 | Unknown |
| 3 | `Thread.sleep` usage | 0 | 25 calls |
| 4 | Flaky test count | <3 | 10 |
| 5 | CI re-run frequency | <5% | ~70% |

### Long-Term KPIs (Post-Remediation)

- **CI Success Rate**: >95% (current: ~7%)
- **Individual Test Failure Rate**: <1% (current: 0.58% - good!)
- **Test Execution Time**: <15 min for full suite (current: ~22 min)
- **Flakiness Incidents**: <1 per month requiring investigation
- **Test Code Maintainability**: Page object coverage >80%

### Monitoring Dashboard

Create `docs/testing/flakiness-dashboard.md` (auto-updated daily):
```markdown
# Test Flakiness Dashboard
**Last Updated**: 2026-01-19 00:00 UTC

## Current Status: 🟢 Healthy

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| CI Success Rate | 96% | >95% | 🟢 |
| Flaky Tests | 2 | <3 | 🟢 |
| Avg Test Time | 14m | <15m | 🟢 |

## Flaky Tests (Past 7 Days)
1. `testAdvancedFeature` - 2 failures / 100 runs (2%)
2. `testEdgeCase` - 1 failure / 100 runs (1%)

## Action Items
- [ ] Investigate `testAdvancedFeature` wait timeout pattern
```

---

## Risk Assessment

### High Risk Items

1. **Breaking existing tests during refactor**
   - **Mitigation**: Incremental migration, parallel old/new patterns initially
   - **Rollback plan**: Keep old helpers available during transition

2. **Performance regression from page objects**
   - **Mitigation**: Benchmark test execution time before/after
   - **Threshold**: <5% slowdown acceptable

3. **Team adoption resistance**
   - **Mitigation**: Pair programming sessions, clear examples
   - **Enforcement**: Code review checklist, CI warnings

### Medium Risk Items

1. **CI infrastructure capacity limits**
   - Reducing parallelism may increase total runtime
   - **Mitigation**: Monitor queue times, scale if needed

2. **Simulator provisioning still flaky**
   - New isolation may expose existing simulator bugs
   - **Mitigation**: Add retry logic, health checks

---

## Dependencies & Prerequisites

### Before Starting Phase 1
- [ ] Verify all CI runs from past week archived
- [ ] Confirm `PlaybackPositionTickerTests` coverage equivalent to deprecated file
- [ ] Create backup branch of current test suite

### Before Starting Phase 2
- [ ] Phase 1 metrics meet targets (>90% CI success)
- [ ] Team review of page object pattern examples
- [ ] Allocate 1-2 hours/day for migration work

### Before Starting Phase 3
- [ ] 50% of tests migrated to new patterns
- [ ] Infrastructure monitoring tools configured
- [ ] GitHub Actions API access verified for flakiness tracker

---

## Timeline Summary

| Phase | Duration | Key Deliverable | Success Metric |
|-------|----------|----------------|----------------|
| **Phase 1** | 2 days | Quarantine deprecated test, add health checks | CI success >90% |
| **Phase 2A** | 5 days | Isolation protocol, base class | Zero state pollution |
| **Phase 2B** | 8 days | Page objects for 5 screens | 50% tests migrated |
| **Phase 2C** | 3 days | Unified wait API | Zero `Thread.sleep` |
| **Phase 3A** | 2 days | Flakiness tracker | Automated reporting |
| **Phase 3B** | 2 days | Runtime budgets | Test timeouts enforced |
| **Phase 3C** | 2 days | CI resource limits | Stable simulator provisioning |
| **Phase 4** | 3 days | Documentation update | Team trained |
| **TOTAL** | ~4 weeks | Stable, maintainable test suite | CI success >95% |

---

## Next Steps (Immediate)

1. **Review this plan** with team (30 min)
2. **Approve Phase 1 actions** (quarantine deprecated test)
3. **Create tracking issue** (e.g., #02.7.4 - Test Architecture Overhaul)
4. **Schedule Phase 1 implementation** (next 48 hours)
5. **Set up monitoring** (flakiness dashboard, CI metrics)

---

## References

- **Issue #02.7**: CI Test Flakiness - Investigation & Infrastructure
- **Issue #12.7**: UI Test Reliability & CI Resilience
- **Issue #27.1.2**: Migrate zpod to Persistent Podcast Repository
- **Docs**:
  - `docs/testing/preventing-flakiness.md`
  - `docs/testing/flakiness-dashboard.md`
  - `docs/testing/UI_TESTING_ADVANCED_PATTERNS.md`
- **Code**:
  - `zpodUITests/UITestHelpers.swift`
  - `zpodUITests/UITestStableWaitHelpers.swift`
  - `zpodUITests/UITestEnvironmentalIsolation.swift`
- **CI Workflow**: `.github/workflows/ci.yml`

---

## Open Questions for Discussion

1. **Should we pause new feature development** during Phase 2-3 refactoring? (Recommended: Yes, to avoid merge conflicts)

2. **Should we delete `PlaybackPositionUITests` after quarantine** or keep it temporarily for rollback? (Current: quarantine for traceability; plan to delete after watch period)

3. **Should page object pattern be mandatory** or opt-in for new tests? (Recommended: Mandatory via linter rule)

4. **Should we parallelize Phase 2A/2B/2C** or sequential? (Recommended: Sequential - each builds on previous)

5. **Should we set a "flakiness SLA"** where CI failures block merges if >X% flaky? (Recommended: Yes, 5% threshold)

---

**End of Investigation Plan**

**Next Action**: Review and approve Phase 1 (quarantine deprecated test) to begin remediation.

# CI Reliability Dashboard

**Last Updated**: 2025-11-28 (Corrected after script bug fix)
**Baseline Period**: 2025-11-08 to 2025-11-27 (19 days)

## ⚠️ CRITICAL UPDATE: Analysis Script Bug Fixed

**Original Issue**: Script crashed on build/infrastructure failures, causing severe bias toward test-execution failures.

**Fix Applied**: Added `|| true` to grep commands to tolerate zero matches.

**Impact**: Revealed that **75% of CI failures are build/infrastructure issues**, not test flakiness!

## Overall Metrics

| Metric | Current Value | Target | Status |
|--------|--------------|--------|--------|
| **CI Run Failure Rate** | **93.4%** | <5% | 🔴 Critical |
| └─ Build/Infrastructure Failures | **~75%** | <5% | 🔴 **PRIMARY ISSUE** |
| └─ Test Execution Failures | **~25%** | <2% | 🔴 Secondary |
| Individual Test Failure Rate | 0.58% | <2% | 🟢 Good |
| Flaky Tests (>1 failure) | 10 | 0 | ⚠️ High |
| CI Re-run Frequency | ~70-80% | <10% | 🔴 Critical |

## Failure Type Breakdown

### 🔴 PRIMARY: Build/Infrastructure Failures (~75% of failures)

| Failure Type | Estimated % | Runs Affected | Investigation Status |
|--------------|-------------|---------------|---------------------|
| Build/Infrastructure (no tests execute) | **75%** | 15/20 sampled | 📋 **Needs Investigation** |

**Common Symptoms**:
- Zero test results in CI logs
- Build failures before test execution
- Simulator boot failures
- Infrastructure timeouts

**Priority**: **CRITICAL** - Must investigate in Phase 2 before addressing test flakiness

---

### ⚠️ SECONDARY: Test Execution Failures (~25% of failures)

## Flakiness by Test Suite (within test-execution failures only)

| Suite | % of Test Failures | Failure Count | % of Total CI Failures | Flakiest Test | Severity | Last Updated |
|-------|-------------------|---------------|----------------------|---------------|----------|--------------|
| **SwipePresetSelectionTests** | 45.5% | 10 | ~11.4% | testPlaybackPresetAppliesCorrectly (4) | ⚠️ High | 2025-11-28 |
| **BatchOperationUITests** | 18.2% | 4 | ~4.5% | testLaunchConfiguredApp_WithForcedOverlayDoesNotWait (1) | ⚡ Medium | 2025-11-28 |
| **SwipeActionManagementTests** | 13.6% | 3 | ~3.4% | testManagingActionsEndToEnd (3) | ⚠️ High | 2025-11-28 |
| **SwipeExecutionTests** | 9.1% | 2 | ~2.3% | testLeadingAndTrailingSwipesExecute (2) | ⚡ Medium | 2025-11-28 |
| **SwipeConfigurationUIDisplayTests** | 9.1% | 2 | ~2.3% | testAllSectionsAppearInSheet (2) | ⚡ Medium | 2025-11-28 |
| **SwipePersistenceTests** | 4.5% | 1 | ~1.1% | testSeededConfigurationPersistsAcrossControls (1) | ⚡ Medium | 2025-11-28 |

## Top 10 Flakiest Individual Tests

| Rank | Test | Suite | Failures | Severity | Status |
|------|------|-------|----------|----------|--------|
| 1 | testPlaybackPresetAppliesCorrectly | SwipePresetSelectionTests | 4 | 🔥 Critical | 📋 Needs Fix |
| 2 | testDownloadPresetAppliesCorrectly | SwipePresetSelectionTests | 4 | 🔥 Critical | 📋 Needs Fix |
| 3 | testManagingActionsEndToEnd | SwipeActionManagementTests | 3 | 🔥 Critical | 📋 Needs Fix |
| 4 | testOrganizationPresetAppliesCorrectly | SwipePresetSelectionTests | 2 | ⚠️ High | 📋 Needs Analysis |
| 5 | testLeadingAndTrailingSwipesExecute | SwipeExecutionTests | 2 | ⚠️ High | 📋 Needs Analysis |
| 6 | testAllSectionsAppearInSheet | SwipeConfigurationUIDisplayTests | 2 | ⚠️ High | 📋 Needs Analysis |
| 7 | testSeededConfigurationPersistsAcrossControls | SwipePersistenceTests | 1 | ⚡ Medium | 👀 Monitor |
| 8 | testLaunchConfiguredApp_WithForcedOverlayDoesNotWait | BatchOperationUITests | 1 | ⚡ Medium | 👀 Monitor |
| 9 | testCriteriaBasedSelection | BatchOperationUITests | 1 | ⚡ Medium | 👀 Monitor |
| 10 | testBatchOperationCancellation | BatchOperationUITests | 1 | ⚡ Medium | 👀 Monitor |

## Flakiness Trend

| Week | CI Failure Rate | Flaky Tests | Notes |
|------|----------------|-------------|-------|
| 2025-11-08 to 2025-11-14 | ~95% | 10 | Issue #131 active development |
| 2025-11-15 to 2025-11-21 | ~94% | 10 | Test refactoring ongoing |
| 2025-11-22 to 2025-11-27 | ~92% | 10 | **Baseline established** |
| 2025-11-28+ | TBD | TBD | Phase 2 fixes starting |

## Root Cause Distribution (Hypothesized)

| Category | % of Failures | Tests Affected |
|----------|--------------|----------------|
| Timing/Synchronization | ~80% | 8 tests |
| State Pollution | ~10% | 1 test |
| Element Discovery | ~10% | 1 test |

## Action Items

### 🔴 CRITICAL Priority (Week 1): Build/Infrastructure Failures

**Must address FIRST** - these cause 75% of CI failures:

- [ ] **Investigate build/infrastructure failure root causes**
  - Examine CI logs from 15 runs with zero test results
  - Categorize failures: build errors, simulator issues, infrastructure timeouts
  - Document common patterns
- [ ] **Identify build stability improvements**
  - Add retry logic for simulator boot
  - Increase infrastructure operation timeouts
  - Add dependency caching
- [ ] **Add build monitoring**
  - Track build success rate separately
  - Alert on build failure spikes

### ⚠️ High Priority (Week 2-3): Test Execution Failures

**After build/infrastructure is stable**:

- [ ] Fix `testPlaybackPresetAppliesCorrectly` (SwipePresetSelectionTests)
- [ ] Fix `testDownloadPresetAppliesCorrectly` (SwipePresetSelectionTests)
- [ ] Fix `testManagingActionsEndToEnd` (SwipeActionManagementTests)

### ⚡ Medium Priority (Week 4+)
- [ ] Analyze remaining flaky tests
- [ ] Implement Phase 3 infrastructure improvements
- [ ] Monitor for new flakiness patterns

## Historical Notes

### 2025-11-28: CORRECTION - Analysis Script Bug Fixed
- **Critical Bug**: Script crashed on runs with zero test results (build/infra failures)
- **Fix**: Added `|| true` to grep commands
- **New Finding**: **75% of failures are build/infrastructure issues**, not test flakiness
- Priority shift: Build stability is PRIMARY issue, test flakiness is SECONDARY
- Updated Phase 2 scope to investigate build failures first

### 2025-11-27: Initial Baseline (BIASED - see correction above)
- Analyzed 150 CI runs (91 usable runs)
- Identified 10 flaky tests across 6 test suites
- **Original (incorrect) finding**: Test flakiness is primary issue
- **Correction**: Script bias caused underestimation of build/infrastructure failures

## Data Sources

- **CI Runs Analyzed**: 150 (last 19 days)
- **Test Executions Analyzed**: 3,779 (from 20 failed runs)
- **Analysis Script**: `scripts/analyze-ci-flakiness.sh`
- **Raw Data**: `/tmp/ci-flakiness-analysis/test-results.csv`
- **Baseline Report**: `dev-log/02.7.1-flakiness-baseline-report.md`

## How to Update This Dashboard

1. Run flakiness analysis script:
   ```bash
   ./scripts/analyze-ci-flakiness.sh 150
   ```

2. Review output at `/tmp/ci-flakiness-analysis/summary.txt`

3. Update metrics in this dashboard

4. Add weekly trend entry

5. Move fixed tests to "Historical Fixes" section

## References

- Master Issue: #145 (02.7 - CI Test Flakiness)
- Phase 1: #146 (Identification & Metrics) - ✅ Complete
- Phase 2: #147 (Root Cause Analysis) - 🔄 In Progress
- Phase 3: #148 (Infrastructure Improvements) - ⏳ Pending

---

**Status Indicators**:
- 🔴 Critical (immediate action required)
- ⚠️ High (prioritize soon)
- ⚡ Medium (monitor/address when possible)
- 🟢 Good (within acceptable range)
- ✅ Fixed (no longer flaky)

**Severity Indicators**:
- 🔥 Critical (>10% failure rate or 3+ failures)
- ⚠️ High (5-10% failure rate or 2 failures)
- ⚡ Medium (2-5% failure rate or 1 failure)
- 👀 Monitor (watch for recurrence)

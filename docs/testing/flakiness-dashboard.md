# CI Test Flakiness Dashboard

**Last Updated**: 2025-11-27
**Baseline Period**: 2025-11-08 to 2025-11-27 (19 days)

## Overall Metrics

| Metric | Current Value | Target | Status |
|--------|--------------|--------|--------|
| CI Run Failure Rate | **93.4%** | <5% | 🔴 Critical |
| Individual Test Failure Rate | 0.58% | <2% | 🟢 Good |
| Flaky Tests (>1 failure) | 10 | 0 | 🔴 Critical |
| CI Re-run Frequency | ~70-80% | <10% | 🔴 Critical |

## Flakiness by Test Suite

| Suite | Flakiness Rate | Failure Count | Flakiest Test | Severity | Last Updated |
|-------|----------------|---------------|---------------|----------|--------------|
| **SwipePresetSelectionTests** | 45.5% | 10 | testPlaybackPresetAppliesCorrectly (4) | 🔥 Critical | 2025-11-27 |
| **BatchOperationUITests** | 18.2% | 4 | testLaunchConfiguredApp_WithForcedOverlayDoesNotWait (1) | ⚠️ High | 2025-11-27 |
| **SwipeActionManagementTests** | 13.6% | 3 | testManagingActionsEndToEnd (3) | 🔥 Critical | 2025-11-27 |
| **SwipeExecutionTests** | 9.1% | 2 | testLeadingAndTrailingSwipesExecute (2) | ⚠️ High | 2025-11-27 |
| **SwipeConfigurationUIDisplayTests** | 9.1% | 2 | testAllSectionsAppearInSheet (2) | ⚠️ High | 2025-11-27 |
| **SwipePersistenceTests** | 4.5% | 1 | testSeededConfigurationPersistsAcrossControls (1) | ⚡ Medium | 2025-11-27 |

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

### 🔥 Critical Priority (Week 1)
- [ ] Fix `testPlaybackPresetAppliesCorrectly` (SwipePresetSelectionTests)
- [ ] Fix `testDownloadPresetAppliesCorrectly` (SwipePresetSelectionTests)
- [ ] Fix `testManagingActionsEndToEnd` (SwipeActionManagementTests)

### ⚠️ High Priority (Week 2-3)
- [ ] Analyze `testOrganizationPresetAppliesCorrectly` root cause
- [ ] Analyze `testLeadingAndTrailingSwipesExecute` root cause
- [ ] Analyze `testAllSectionsAppearInSheet` root cause

### ⚡ Medium Priority (Week 4+)
- [ ] Monitor 1-failure tests for recurrence
- [ ] Implement Phase 3 infrastructure improvements

## Historical Notes

### 2025-11-27: Baseline Established
- Analyzed 150 CI runs (91 usable runs)
- Identified 10 flaky tests across 6 test suites
- **Critical finding**: 93.4% CI failure rate driven by small number of flaky tests
- Created Issue #147 for Phase 2 root cause analysis

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

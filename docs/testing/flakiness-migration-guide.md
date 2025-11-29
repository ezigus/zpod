# Test Flakiness Migration Guide

**Issue**: #148 (Phase 3 - Infrastructure Improvements)
**Date**: 2025-11-29
**Purpose**: Concrete examples of applying new infrastructure to existing flaky tests

## Overview

This guide shows how to migrate existing flaky tests to use the new infrastructure. The infrastructure provides:

1. **Automatic cleanup** (already integrated into base class)
2. **Deterministic post-scroll waits** (already fixed in `settle()`)
3. **Diagnostic helpers** for understanding failures
4. **Stable wait primitives** for animations
5. **Improved element discovery** with scrolling

## Automatic Improvements

**Good news**: Most tests benefit automatically from infrastructure fixes!

### Already Applied (No Migration Needed)

✅ **Cleanup in tearDown** - All `SwipeConfigurationTestCase` subclasses now automatically:
```swift
override func tearDownWithError() throws {
  // This runs automatically for ALL tests!
  performSwipeConfigurationCleanup()  // Clears UserDefaults + Keychain
  // ... other cleanup
}
```

✅ **Fixed settle() timing** - All tests using `ensureVisibleInSheet` now automatically:
```swift
// Scrolls and waits 300ms (was 50ms) for SwiftUI to materialize
ensureVisibleInSheet(identifier: "preset", container: sheet, scrollAttempts: 6)
```

**Impact**: SwipePresetSelectionTests went from 66.7% → 100% pass rate with NO test code changes!

---

## Migration Examples

### Example 1: SwipePresetSelectionTests (COMPLETED ✅)

**Flakiness**: 47% of all test failures
**Root Cause**: Infrastructure issue (settle() timeout too short)
**Fix**: Infrastructure change (no test migration needed)

**Before** (failing 1 of 3 tests):
```swift
func testDownloadPresetAppliesCorrectly() throws {
  try reuseOrOpenConfigurationSheet(resetDefaults: true)
  applyPreset(identifier: "SwipeActions.Preset.Download")  // ❌ Failed: element not found
  assertSaveEnabledAfterPreset()
  assertConfiguration(
    leadingActions: ["Download", "Mark Played"],
    trailingActions: ["Archive", "Delete"]
  )
}
```

**After** (passing 3 of 3 tests):
```swift
// NO CODE CHANGES NEEDED!
// Infrastructure fixes applied automatically:
// 1. settle() now waits 300ms after scroll
// 2. cleanup runs in tearDown automatically
```

**Result**: 100% pass rate with zero test code changes

---

### Example 2: Adding Diagnostics to Flaky Element Discovery

**Problem**: Element not appearing, but test doesn't explain why

**Before** (poor diagnostic):
```swift
let button = app.buttons["Submit"]
XCTAssertTrue(button.exists)  // ❌ Fails with: "XCTAssertTrue failed"
button.tap()
```

**After** (with diagnostics):
```swift
let button = app.buttons["Submit"]
guard button.exists else {
  // Use diagnostic helper to understand WHY element is missing
  let diagnosis = diagnoseElementAbsence(button, preconditions: [
    "Data loaded": { !app.activityIndicators.firstMatch.exists },
    "Modal dismissed": { !app.sheets.firstMatch.exists },
    "Sheet open": { swipeActionsSheetListContainer() != nil }
  ])
  XCTFail(diagnosis)
  return
}
button.tap()
```

**Output on failure**:
```
❌ Element not found: 'Submit'
   Type: Button

📋 Preconditions:
   ✅ Data loaded
   ❌ Modal dismissed
   ✅ Sheet open

💡 Possible fixes:
   • Use discoverWithScrolling() if element is off-screen
   • Verify state setup (seed applied, data loaded, etc.)
   • Check if modal/alert is blocking element
   • Ensure cleanup ran (no state pollution from previous test)
```

---

### Example 3: Waiting for Animations Before Interaction

**Problem**: Tapping element mid-animation fails

**Before** (flaky):
```swift
app.buttons["TabBar.Library"].tap()
let libraryView = app.otherElements["Library.Container"]
// ❌ Immediate assertion can fail during animation
XCTAssertTrue(libraryView.exists)
```

**After** (stable):
```swift
app.buttons["TabBar.Library"].tap()
let libraryView = app.otherElements["Library.Container"]

// Wait for page load (view transition)
XCTAssertTrue(libraryView.waitForPageLoad(timeout: 2.0))

// Wait for animation to complete before assertions
XCTAssertTrue(libraryView.waitForAnimationComplete(timeout: 1.0))

// Now assertions are stable
XCTAssertTrue(libraryView.exists)
```

---

### Example 4: Element Discovery with Scroll

**Problem**: Element off-screen due to SwiftUI lazy loading

**Before** (element not found):
```swift
let cell = app.cells["Episode-123"]
XCTAssertTrue(cell.exists)  // ❌ Fails: element not materialized yet
cell.tap()
```

**After** (deterministic discovery):
```swift
let scrollView = app.scrollViews["Episode.List"]
let cell = app.cells["Episode-123"]

// Scroll to discover element if needed
XCTAssertTrue(cell.discoverWithScrolling(
  in: scrollView,
  timeout: 5.0,
  maxScrollAttempts: 10,
  scrollDirection: .up
))

// Wait briefly for SwiftUI to stabilize after scroll
XCTAssertTrue(cell.waitBriefly(timeout: 0.3))

cell.tap()
```

---

### Example 5: Verifying Preconditions Before Test

**Problem**: Test fails due to incorrect setup (seed not applied, etc.)

**Before** (unclear failure):
```swift
func testPresetAppliesCorrectly() {
  seedConfiguration(presets: ["Download", "Playback"])
  launchSeededApp(resetDefaults: true)
  openSwipeConfigurationSheet()

  // ❌ Fails mysteriously if seed didn't apply
  let preset = app.buttons["SwipeActions.Preset.Download"]
  XCTAssertTrue(preset.exists)
}
```

**After** (explicit verification):
```swift
func testPresetAppliesCorrectly() {
  seedConfiguration(presets: ["Download", "Playback"])
  launchSeededApp(resetDefaults: true)

  // Verify preconditions BEFORE opening sheet
  verifyPreconditions([
    "Seed applied": {
      let defaults = UserDefaults(suiteName: swipeDefaultsSuite)
      return defaults?.data(forKey: "global_ui_settings") != nil
    },
    "App running": { app.state == .runningForeground },
    "No modals": { !app.sheets.firstMatch.exists }
  ])

  openSwipeConfigurationSheet()

  let preset = app.buttons["SwipeActions.Preset.Download"]
  XCTAssertTrue(preset.exists)  // Now we know seed was applied!
}
```

---

### Example 6: Safe Tap with Stability Check

**Problem**: Tap fails because element is animating

**Before** (flaky tap):
```swift
let button = app.buttons["Submit"]
button.tap()  // ❌ May fail if button is mid-animation
```

**After** (stable tap):
```swift
let button = app.buttons["Submit"]

// Tap safely with stability check
try button.tapSafely(
  waitForStability: true,
  stabilityTimeout: 1.0,
  context: "Submit button in checkout flow"
)
```

Or for multiple interactions:
```swift
// Wait for animation once, then tap multiple times
XCTAssertTrue(button.waitForAnimationComplete())
button.tap()  // Stable now
```

---

### Example 7: Handling View Transitions

**Problem**: Asserting on new view before transition completes

**Before** (race condition):
```swift
app.buttons["Settings"].tap()
let settingsView = app.otherElements["Settings.Container"]
XCTAssertTrue(settingsView.exists)  // ❌ May fail during transition
```

**After** (wait for transition):
```swift
let homeView = app.otherElements["Home.Container"]
app.buttons["Settings"].tap()

// Wait for transition to complete
XCTAssertTrue(waitForTransition(
  from: homeView,
  to: app.otherElements["Settings.Container"],
  timeout: 2.0,
  requireStability: true
))

// Now safe to assert
let settingsView = app.otherElements["Settings.Container"]
XCTAssertTrue(settingsView.exists)
```

---

## Migration Checklist

When migrating a flaky test:

### 1. Check Automatic Fixes First
- [ ] Does test inherit from `SwipeConfigurationTestCase`?
  - ✅ Cleanup runs automatically
  - ✅ Scroll settle time already fixed
- [ ] Does test use `ensureVisibleInSheet`?
  - ✅ Already uses improved settle() timing
- [ ] Run test first - may already be fixed!

### 2. Add Diagnostics
- [ ] Replace assertions with diagnostic helpers where useful
- [ ] Add `diagnoseElementAbsence()` for element not found failures
- [ ] Add `verifyPreconditions()` for setup verification

### 3. Use Appropriate Waits
- [ ] **After page load**: Use `waitForPageLoad(2.0s)`
- [ ] **After scroll**: Use `waitBriefly(0.5s)`
- [ ] **After animation**: Use `waitForAnimationComplete(1.0s)`
- [ ] **For transitions**: Use `waitForTransition()`
- [ ] **Never**: Add arbitrary sleep() or retry loops!

### 4. Improve Element Discovery
- [ ] Use `discoverWithScrolling()` for off-screen elements
- [ ] Use `waitForHittable()` before taps
- [ ] Use `tapSafely()` for elements that may be animating

### 5. Verify Cleanup
- [ ] Check `tearDown()` calls cleanup (automatic for `SwipeConfigurationTestCase`)
- [ ] Use `verifyUserDefaultsIsEmpty()` if debugging state pollution
- [ ] Use `logUserDefaultsState()` to inspect persisted data

---

## Common Patterns

### Pattern 1: Scroll + Wait + Tap
```swift
// Discover element with scroll
XCTAssertTrue(element.discoverWithScrolling(in: scrollView, timeout: 5.0))

// Wait briefly for SwiftUI to stabilize
XCTAssertTrue(element.waitBriefly(timeout: 0.3))

// Tap safely
try element.tapSafely(waitForStability: true)
```

### Pattern 2: Verify State + Act + Assert
```swift
// Verify preconditions
verifyPreconditions([
  "Data loaded": { !app.activityIndicators.firstMatch.exists },
  "Correct screen": { app.navigationBars["Settings"].exists }
])

// Act
app.buttons["Save"].tap()

// Wait for result
XCTAssertTrue(waitForTransition(to: app.alerts["Saved"], timeout: 2.0))
```

### Pattern 3: Diagnose on Failure
```swift
let element = app.buttons["Submit"]
guard element.exists else {
  XCTFail(diagnoseElementAbsence(element, preconditions: [
    "Sheet open": { /* check */ },
    "Data ready": { /* check */ }
  ]))
  return
}
```

---

## Testing Your Migration

After migrating a test:

1. **Run locally 10 times**: Should pass 10/10
   ```bash
   for i in {1..10}; do
     ./scripts/run-xcode-tests.sh -t YourTest || break
   done
   ```

2. **Check CI**: Should pass consistently over 1 week

3. **Review failures**: Should have clear diagnostic messages

---

## Real-World Results

### SwipePresetSelectionTests Migration

**Before**:
- Pass rate: 66.7% (2/3 tests)
- Failure: "Element not found after 1.5s"
- Root cause: Unknown

**After** (infrastructure fixes only):
- Pass rate: 100% (3/3 tests)
- No test code changes needed
- Root cause: Infrastructure timing issue (now fixed)

**Migration effort**: 0 lines of test code changed
**Improvement**: +33.3% pass rate
**Time saved**: ~40s per test run (no retries needed)

---

## When NOT to Migrate

Don't add infrastructure if:
- ✅ Test already passes consistently
- ✅ Test is simple with no timing dependencies
- ✅ Test doesn't interact with UI (unit test)

**Philosophy**: Add infrastructure only when needed, not preemptively.

---

## Questions?

See main documentation:
- [Preventing Flakiness Guide](./preventing-flakiness.md) - Full API reference
- [Phase 3 Infrastructure](../../Issues/02.7.3-flakiness-infrastructure-improvements.md) - Implementation details
- [Flakiness Dashboard](./flakiness-dashboard.md) - Current metrics

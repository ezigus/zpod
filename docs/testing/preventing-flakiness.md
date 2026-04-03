# Preventing Test Flakiness

**Created for**: Issue #148 (02.7.3 - CI Test Flakiness: Phase 3 - Infrastructure Improvements)
**Last Updated**: 2025-12-04 (Updated to match actual implementation)

## Overview

This guide documents the test infrastructure designed to prevent flaky test failures. The implementation follows a **deterministic, no-retry philosophy**: "UI elements appear immediately or not at all - if element isn't there, fix the root cause instead of retrying."

**SwiftUI List rule (approved pattern)**: Always perform a *just-in-time scroll* immediately before interaction. Pre-materializing sections alone is insufficient—SwiftUI unmaterializes rows when scrolled away. Scroll directly to the target and tap right after. Avoid lingering overlays or helper views that can occlude targets.

The infrastructure addresses three main categories of test flakiness:

1. **Timing/Synchronization Issues** (70% of failures) - Deterministic waits (not retries)
2. **Race Conditions/Animations** (20% of failures) - Stable wait primitives
3. **State Pollution** (10% of failures) - Cleanup utilities

---

## Infrastructure Files

| File | Purpose | Key Functions |
|------|---------|---------------|
| `UITestRetryHelpers.swift` | Diagnostic helpers and minimal waits | `diagnoseElementState`, `tapSafely`, `waitBriefly`, `waitForPageLoad` |
| `UITestStableWaitHelpers.swift` | Stability waits for animations | `waitForStable`, `waitForHittable`, `waitForTransition`, `waitForAnimationComplete` |
| `UITestEnvironmentalIsolation.swift` | Cleanup utilities | `performStandardCleanup`, `clearUserDefaults`, `clearKeychain` |
| `UITestImprovedElementDiscovery.swift` | Element discovery with scrolling | `discoverWithScrolling`, `discoverInCollection`, `findElementWithFallback` |

---

## Quick Reference

### 1. Minimal Waits (UITestRetryHelpers.swift)

Use **only** for brief waits after page load or scroll - not as retry mechanisms.

```swift
// After page load (view transition)
let view = app.otherElements["Settings.Container"]
XCTAssertTrue(view.waitForPageLoad(timeout: 2.0))

// After scroll (SwiftUI lazy materialization)
scrollView.swipeUp()
XCTAssertTrue(element.waitBriefly(timeout: 0.5))
```

**Philosophy**: If element doesn't appear within short timeout, it won't appear - fix the root cause.

---

### 2. Diagnostic Helpers (UITestRetryHelpers.swift)

Understand **why** tests fail instead of retrying blindly.

```swift
let button = app.buttons["Submit"]
guard button.exists else {
  // Diagnose WHY element is missing
  let diagnosis = diagnoseElementState(button, preconditions: [
    "Data loaded": { !app.activityIndicators.firstMatch.exists },
    "Modal dismissed": { !app.sheets.firstMatch.exists }
  ])
  XCTFail(diagnosis)
  return
}
```

**Output on failure**:
```
❌ Element not found: 'Submit'
   Type: Button

📋 Preconditions:
   ✅ Data loaded
   ❌ Modal dismissed

💡 Possible fixes:
   • Use discoverWithScrolling() if element is off-screen
   • Verify state setup (seed applied, data loaded, etc.)
   • Check if modal/alert is blocking element
```

---

### 3. Stable Wait Primitives (UITestStableWaitHelpers.swift)

Wait for animations to complete before interacting.

```swift
// Wait for element to stabilize (frame stops changing)
let button = app.buttons["Submit"]
XCTAssertTrue(button.waitForStable(timeout: 5.0))
button.tap()  // Safe - element is stable

// Wait for animation to complete
app.buttons["TabBar.Library"].tap()
let libraryView = app.otherElements["Library.Container"]
XCTAssertTrue(libraryView.waitForAnimationComplete(timeout: 2.0))

// Wait for element to be hittable AND stable
XCTAssertTrue(button.waitForHittable(timeout: 5.0, requireStability: true))
button.tap()  // Guaranteed to succeed

// Wait for view transition
app.buttons["Settings"].tap()
XCTAssertTrue(waitForTransition(
  from: app.otherElements["Home.Container"],
  to: app.otherElements["Settings.Container"],
  timeout: 3.0
))
```

**Key Functions**:
- `waitForStable()` - Wait for frame to stop changing (animation complete)
- `waitForAnimationComplete()` - Convenience for animation completion
- `waitForHittable()` - Wait for element to be hittable AND stable
- `waitForTransition()` - Wait for view transition to complete
- `waitForModalPresentation()` - Wait for sheet/alert to present

---

### 4. Element Discovery (UITestImprovedElementDiscovery.swift)

Automatically scroll to find lazy-loaded elements.

```swift
// Discover element with automatic scrolling
let scrollView = app.scrollViews["Episode.List"]
let episode = app.buttons["Episode-123"]
XCTAssertTrue(episode.discoverWithScrolling(
  in: scrollView,
  timeout: 5.0,
  maxScrollAttempts: 10,
  scrollDirection: .up
))
episode.tap()

// Discover cell in collection view
let table = app.tables["Episode.List"]
let cell = app.cells["Episode-123"]
XCTAssertTrue(cell.discoverInCollection(table, timeout: 5.0))

// Find element with multiple strategies
let button = findElementWithFallback(
  in: app,
  identifier: "Submit.Button",
  label: "Submit",
  type: .button,
  timeout: 2.0
)
```

---

### 5. Environmental Isolation (UITestEnvironmentalIsolation.swift)

Clean up state between tests to prevent pollution.

```swift
// Standard cleanup (UserDefaults + Keychain)
override func tearDown() {
  performStandardCleanup(suiteName: "us.zig.zpod.swipe-uitests")
  super.tearDown()
}

// SwipeConfiguration-specific cleanup
override func tearDown() {
  performSwipeConfigurationCleanup()
  super.tearDown()
}

// Reset app state (terminate + relaunch)
func testFreshAppState() {
  resetAppState(app: app)
  // App is now in fresh state
}

// Verification helpers (for debugging)
XCTAssertTrue(verifyUserDefaultsIsEmpty(suiteName: "us.zig.zpod.swipe-uitests"))
logUserDefaultsState(suiteName: "us.zig.zpod.swipe-uitests")
```

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

### Pattern 2: Diagnose on Failure
```swift
let element = app.buttons["Submit"]
guard element.exists else {
  let diagnosis = diagnoseElementState(element, preconditions: [
    "Sheet open": { swipeActionsSheetListContainer() != nil },
    "Data ready": { verifySwipeSeedApplied() }
  ])
  XCTFail(diagnosis)
  return
}
```

### Pattern 3: Wait for Transition
```swift
let homeView = app.otherElements["Home.Container"]
app.buttons["Settings"].tap()

waitForTransition(
  from: homeView,
  to: app.otherElements["Settings.Container"],
  timeout: 2.0,
  requireStability: true
)
```

### Pattern 4: Verify Preconditions
```swift
verifyPreconditions([
  "Seed applied": { verifySwipeSeedApplied() },
  "App launched": { app.state == .runningForeground },
  "No modals": { !app.sheets.firstMatch.exists }
])
```

---

## Best Practices

### ✅ DO: Use Deterministic Waits
```swift
// Wait for element to exist
XCTAssertTrue(button.waitForExistence(timeout: 5.0))

// Wait for animation to complete
XCTAssertTrue(button.waitForAnimationComplete())

// Wait for page load
XCTAssertTrue(view.waitForPageLoad(timeout: 2.0))
```

### ✅ DO: Diagnose Failures
```swift
// Use diagnostic helpers to understand WHY test failed
guard element.exists else {
  XCTFail(diagnoseElementState(element, preconditions: [...]))
  return
}
```

### ✅ DO: Clean Up State
```swift
// Always clean up in tearDown
override func tearDown() {
  performStandardCleanup(suiteName: "us.zig.zpod.swipe-uitests")
  super.tearDown()
}
```

### ❌ DON'T: Use Retry Loops
```swift
// ❌ BAD: Retry loops hide root causes
for _ in 0..<3 {
  if element.exists { break }
  sleep(1)
}

// ✅ GOOD: Fix the root cause
XCTAssertTrue(element.discoverWithScrolling(in: scrollView, timeout: 5.0))
```

### ❌ DON'T: Use Arbitrary Sleeps
```swift
// ❌ BAD: Arbitrary sleep
sleep(2)
element.tap()

// ✅ GOOD: Wait for stability
XCTAssertTrue(element.waitForStable())
element.tap()
```

### ❌ DON'T: Assume Elements Exist
```swift
// ❌ BAD: Assumes element exists
app.buttons["Submit"].tap()

// ✅ GOOD: Wait for element
let button = app.buttons["Submit"]
XCTAssertTrue(button.waitForExistence(timeout: 5.0))
button.tap()
```

### ❌ DON'T: Tap-and-Hope with Poll Loops

```swift
// ❌ BAD: "Single-tap-and-hope" — taps without verifying hittability,
// then polls in a busy loop. If the tap doesn't register (element was
// mid-animation, behind an overlay, or not yet interactive), the entire
// timeout is wasted polling for a state change that will never come.
let playButton = app.buttons["Play"]
guard playButton.waitForExistence(timeout: 4.0) else { return false }
playButton.tap()
return waitUntil(timeout: 8.0, pollInterval: 0.1) {
    app.buttons["Pause"].exists
}

// ✅ GOOD: Verify hittability before tapping, then use XCTest's native
// event-driven waitForExistence. The hittable check ensures the tap will
// be delivered to an interactive element; waitForExistence uses KVO
// internally and reacts immediately when the element appears.
let playButton = app.buttons.matching(identifier: "Play").firstMatch
guard playButton.waitUntil(.hittable, timeout: adaptiveShortTimeout) else {
    return false
}
playButton.tap()
let pauseButton = app.buttons.matching(identifier: "Pause").firstMatch
return pauseButton.waitForExistence(timeout: adaptiveTimeout)
```

**Why this matters**: `waitForExistence` only checks the accessibility tree — an element can "exist" while being covered by an overlay, mid-transition, or not yet hittable. Tapping a non-hittable element is silently swallowed by XCUITest, producing a timeout that looks like a flaky test but is actually a deterministic failure. The fix is never "increase the timeout" — it is "verify the element is interactive before acting on it."

### ❌ DON'T: Increase Timeouts to Fix Flakiness

```swift
// ❌ BAD: Test fails under load → increase timeout → passes → breaks
// again next time the machine is slower. This is the #1 anti-pattern
// in UI testing and it propagates across the codebase.
let adaptiveTimeout: TimeInterval = 12.0  // was 8.0, then 10.0...
let adaptiveShortTimeout: TimeInterval = 6.0  // was 3.0, then 4.0...

// ✅ GOOD: If a test fails under load, the tap or verification is wrong.
// Use hittable waits, predicate-based expectations, and diagnose WHY
// the element isn't appearing rather than waiting longer for it.
```

**Pipeline note for Shipwright agents**: When a UI test fails, NEVER increase an existing timeout value as a fix. Instead:
1. Read the test log to find where exactly it hung or timed out
2. Check whether the action used `waitForExistence` vs `waitUntil(.hittable)`
3. Replace poll-based waits with `XCTNSPredicateExpectation`
4. If the element genuinely doesn't appear, fix the production code or test setup

---

## Migration Guide

For detailed examples of migrating existing flaky tests, see:
- **[flakiness-migration-guide.md](./flakiness-migration-guide.md)** - Concrete examples with before/after code

---

## Testing Infrastructure

To verify infrastructure works correctly:

1. **Run tests locally 10 times** - should pass 10/10
   ```bash
   for i in {1..10}; do
     ./scripts/run-xcode-tests.sh -t YourTest || break
   done
   ```

2. **Monitor CI success rate** over 1 week

3. **Verify cleanup effectiveness**:
   ```swift
   func testCleanupWorks() {
     // Pollute state
     UserDefaults(suiteName: "us.zig.zpod.swipe-uitests")?.set("test", forKey: "key")

     // Clean up
     performStandardCleanup(suiteName: "us.zig.zpod.swipe-uitests")

     // Verify
     XCTAssertTrue(verifyUserDefaultsIsEmpty(suiteName: "us.zig.zpod.swipe-uitests"))
   }
   ```

---

## Related Documentation

- [Test Flakiness Migration Guide](./flakiness-migration-guide.md) - Concrete migration examples
- [Phase 3 Infrastructure Improvements](../../Issues/02.7.3-flakiness-infrastructure-improvements.md) - Implementation details
- [CI Flakiness Dashboard](./flakiness-dashboard.md) - Current metrics

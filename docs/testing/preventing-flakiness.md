# Preventing Test Flakiness

**Created for**: Issue #148 (02.7.3 - CI Test Flakiness: Phase 3 - Infrastructure Improvements)
**Last Updated**: 2025-12-04 (PR finalization with code review fixes)

## ⚠️ IMPORTANT: Documentation Status

**This file contains outdated documentation** describing a retry-based architecture that was **NOT implemented**.

The actual implementation follows a **deterministic, no-retry philosophy**: "UI elements appear immediately or not at all - if element isn't there, fix the root cause instead of retrying."

**For actual implementation**, see:
- `UITestRetryHelpers.swift` - Diagnostic helpers (diagnoseElementState, verifyPreconditions, tapSafely)
- `UITestStableWaitHelpers.swift` - Stability waits (waitForStable, waitForHittable, waitForTransition)
- `UITestEnvironmentalIsolation.swift` - Cleanup utilities
- `UITestImprovedElementDiscovery.swift` - Element discovery with scrolling
- `flakiness-migration-guide.md` - Concrete migration examples

Functions referenced below (retryOnFailure, tapWithRetry, etc.) **do not exist** in the codebase.

---

## Overview (OUTDATED - See note above)

This guide documents the test infrastructure helpers designed to prevent flaky test failures. These utilities address the three main categories of test flakiness:

1. **Timing/Synchronization Issues** (70% of failures) - ~~Retry mechanisms~~ **Deterministic waits**
2. **Race Conditions/Animations** (20% of failures) - Stable wait primitives
3. **State Pollution** (10% of failures) - Cleanup utilities

## Quick Reference

### ✅ Always Use Waits

**❌ Bad**: Assumes element exists immediately
```swift
app.buttons["Submit"].tap()
```

**✅ Good**: Waits for element to exist
```swift
let button = app.buttons["Submit"]
XCTAssertTrue(button.waitForExistence(timeout: 5.0))
button.tap()
```

**✅ Better**: Uses retry mechanism
```swift
try app.buttons["Submit"].tapWithRetry(attempts: 3)
```

### ✅ Wait for Stable Elements

**❌ Bad**: Taps element that may be mid-animation
```swift
element.tap()  // May fail if element is animating
```

**✅ Good**: Waits for element to stabilize
```swift
XCTAssertTrue(element.waitForStable(timeout: 5.0))
element.tap()
```

**✅ Better**: Waits for animation completion
```swift
XCTAssertTrue(element.waitForAnimationComplete(timeout: 2.0))
element.tap()
```

### ✅ Retry Flaky Operations

**❌ Bad**: Fails immediately on timing issues
```swift
let value = complexUIInteraction()  // Might fail due to async
```

**✅ Good**: Retries with backoff
```swift
let value = try retryOnFailure(attempts: 3, delay: 0.5) {
  try complexUIInteraction()
}
```

### ✅ Clean Up State

**❌ Bad**: State leaks between tests
```swift
override func tearDown() {
  super.tearDown()
}
```

**✅ Good**: Clears persistent state
```swift
override func tearDown() {
  performStandardCleanup(suiteName: "us.zig.zpod.swipe-uitests")
  super.tearDown()
}
```

---

## 1. Retry Mechanisms

**File**: `UITestRetryHelpers.swift`
**Addresses**: 70% of test failures (timing/synchronization category)

### 1.1 General Retry

Retry any operation that might fail due to timing:

```swift
let result = try retryOnFailure(attempts: 3, delay: 0.5) {
  guard someAsyncState.isReady else {
    throw TestRetryError.operationFailed(reason: "State not ready")
  }
  return someAsyncState.value
}
```

**Parameters**:
- `attempts`: Maximum retry attempts (default: 3)
- `delay`: Initial delay between attempts (default: 0.5s)
- `useExponentialBackoff`: Doubles delay each retry (default: true)

### 1.2 Element Discovery Retry

Retry element queries with automatic existence checking:

```swift
let button = try retryElementDiscovery(attempts: 3) {
  app.buttons["Submit"]
} operation: { element in
  XCTAssertTrue(element.exists)
  element.tap()
  return element
}
```

### 1.3 Tap with Retry

Tap elements with automatic hittability checking:

```swift
try retryTap(
  on: app.buttons["Submit"],
  attempts: 3,
  description: "Submit button"
)
```

### 1.4 Element Extension: tapWithRetry

Convenience method on XCUIElement:

```swift
try app.buttons["Submit"].tapWithRetry(attempts: 3)
```

### 1.5 Retry Assertions

Retry assertions that depend on async state:

```swift
try retryAssertion(attempts: 3) {
  XCTAssertTrue(element.isSelected, "Element should be selected")
}
```

---

## 2. Stable Wait Primitives

**File**: `UITestStableWaitHelpers.swift`
**Addresses**: 20% of test failures (race conditions, animations)

### 2.1 Frame Stability

Wait for element's frame to stop changing (animation complete):

```swift
let button = app.buttons["Submit"]
XCTAssertTrue(button.waitForStable(timeout: 5.0))
button.tap()  // Safe - frame is stable
```

**Parameters**:
- `timeout`: Max time to wait for stability (default: 5.0s)
- `stabilityWindow`: Duration frame must remain stable (default: 0.5s)
- `checkInterval`: How often to check frame (default: 0.05s)

### 2.2 Animation Completion

Wait for animations to complete:

```swift
app.buttons["TabBar.Library"].tap()
let libraryView = app.otherElements["Library.Container"]
XCTAssertTrue(libraryView.waitForAnimationComplete(timeout: 2.0))
// Library view is now stable
```

### 2.3 Hittable with Stability

Wait for element to be hittable AND stable:

```swift
let button = app.buttons["Submit"]
XCTAssertTrue(button.waitForHittable(
  timeout: 5.0,
  requireStability: true
))
button.tap()  // Guaranteed to succeed
```

### 2.4 Value Stability

Wait for element's value to stop changing:

```swift
let statusLabel = app.staticTexts["Status"]
statusLabel.waitForValueStable(timeout: 3.0)
XCTAssertEqual(statusLabel.value as? String, "Complete")
```

### 2.5 State Waiting

Wait for boolean conditions with polling:

```swift
waitForState(timeout: 5.0, pollInterval: 0.1) {
  app.tabBars.buttons["Library"].isSelected
}
```

### 2.6 Transition Waiting

Wait for view transitions to complete:

```swift
app.buttons["Settings"].tap()
waitForTransition(
  from: app.otherElements["Home.Container"],
  to: app.otherElements["Settings.Container"],
  timeout: 3.0
)
```

### 2.7 Modal Presentation

Wait for modals (sheets/alerts) to present:

```swift
app.buttons["Show Alert"].tap()
let alert = app.alerts["Confirmation"]
XCTAssertTrue(waitForModalPresentation(modal: alert, timeout: 2.0))
```

---

## 3. Environmental Isolation

**File**: `UITestEnvironmentalIsolation.swift`
**Addresses**: 10% of test failures (state pollution)

### 3.1 Standard Cleanup

Clear UserDefaults and Keychain between tests:

```swift
override func tearDown() {
  performStandardCleanup(suiteName: "us.zig.zpod.swipe-uitests")
  super.tearDown()
}
```

### 3.2 UserDefaults Cleanup

Clear UserDefaults to prevent state leakage:

```swift
override func tearDown() {
  clearUserDefaults(suiteName: "us.zig.zpod.swipe-uitests")
  super.tearDown()
}
```

### 3.3 Keychain Cleanup

Clear all keychain items:

```swift
override func tearDown() {
  clearKeychain()
  super.tearDown()
}
```

### 3.4 App State Reset

Terminate and relaunch app for fresh state:

```swift
func testFreshAppState() {
  resetAppState(app: app)
  // App is now in fresh state
}
```

### 3.5 SwipeConfiguration Cleanup

Specialized cleanup for SwipeConfiguration tests:

```swift
override func tearDown() {
  performSwipeConfigurationCleanup()
  super.tearDown()
}
```

### 3.6 Targeted Cleanup

Remove specific UserDefaults keys or keychain items:

```swift
// Remove specific key
removeUserDefaultsKey("test_configuration", suiteName: "us.zig.zpod.swipe-uitests")

// Remove specific keychain item
removeKeychainItem(service: "com.test.auth-token", account: "test-user")
```

### 3.7 Verification Helpers

Debug cleanup issues:

```swift
// Verify cleanup worked
XCTAssertTrue(verifyUserDefaultsIsEmpty(suiteName: "us.zig.zpod.swipe-uitests"))

// Log current state for debugging
logUserDefaultsState(suiteName: "us.zig.zpod.swipe-uitests")
```

---

## 4. Improved Element Discovery

**File**: `UITestImprovedElementDiscovery.swift`
**Addresses**: SwiftUI lazy materialization failures

### 4.1 Scroll-Based Discovery

Automatically scroll to find lazy-loaded elements:

```swift
let episodeList = app.scrollViews["Episode.List"]
let episode = app.buttons["Episode-123"]
XCTAssertTrue(episode.discoverWithScrolling(
  in: episodeList,
  timeout: 5.0,
  maxScrollAttempts: 10,
  scrollDirection: .up
))
episode.tap()
```

### 4.2 Collection Discovery

Find cells in tables/collection views:

```swift
let table = app.tables["Episode.List"]
let cell = app.cells["Episode-123"]
XCTAssertTrue(cell.discoverInCollection(table, timeout: 5.0))
```

### 4.3 Wait with Retry and Logging

Enhanced waitForExistence with debugging:

```swift
let button = app.buttons["Submit"]
XCTAssertTrue(button.waitWithRetry(
  timeout: 5.0,
  description: "Submit button in checkout flow",
  logHierarchyOnFailure: true
))
```

### 4.4 Fallback Element Finding

Try multiple strategies to find elements:

```swift
let button = findElementWithFallback(
  in: app,
  identifier: "Submit.Button",
  label: "Submit",
  type: .button,
  timeout: 2.0
)
```

### 4.5 Wait for Any Element

Wait for any of multiple elements (first wins):

```swift
let result = waitForAnyElementToAppear(
  elements: [
    app.staticTexts["Content.Loaded"],
    app.staticTexts["Content.Error"],
    app.activityIndicators["Loading"]
  ],
  timeout: 5.0
)

switch result?.identifier {
case "Content.Loaded":
  // Handle success
case "Content.Error":
  // Handle error
case "Loading":
  // Still loading
default:
  XCTFail("No valid state appeared")
}
```

---

## Common Flakiness Patterns and Solutions

### Pattern 1: Element Not Found

**Symptom**: Test fails with "element not found" or timeout

**Causes**:
- Element hasn't materialized yet (SwiftUI lazy loading)
- Scrolled off-screen
- Animation still in progress

**Solutions**:

```swift
// Solution 1: Use scroll-based discovery
element.discoverWithScrolling(in: scrollView, timeout: 5.0)

// Solution 2: Use retry mechanism
try element.tapWithRetry(attempts: 3)

// Solution 3: Wait for animation complete
element.waitForAnimationComplete()
element.tap()
```

### Pattern 2: Tap Fails Mid-Animation

**Symptom**: Element exists but tap doesn't register

**Causes**:
- Element is mid-animation
- Frame is still changing
- Element not yet hittable

**Solutions**:

```swift
// Solution 1: Wait for stable frame
element.waitForStable()
element.tap()

// Solution 2: Wait for hittable + stable
element.waitForHittable(requireStability: true)
element.tap()

// Solution 3: Use tap with retry
try element.tapWithRetry()
```

### Pattern 3: Race Condition on State

**Symptom**: Assertion fails but state is "eventually" correct

**Causes**:
- Async state update
- SwiftUI view update delay

**Solutions**:

```swift
// Solution 1: Retry assertion
try retryAssertion(attempts: 3) {
  XCTAssertTrue(element.isSelected)
}

// Solution 2: Wait for state
waitForState(timeout: 3.0) {
  element.isSelected
}

// Solution 3: Wait for value stability
element.waitForValueStable()
XCTAssertEqual(element.value as? String, "expected")
```

### Pattern 4: State Pollution

**Symptom**: Test passes in isolation but fails in suite

**Causes**:
- Previous test left UserDefaults/Keychain data
- In-memory state leaked

**Solutions**:

```swift
// Solution 1: Add standard cleanup
override func tearDown() {
  performStandardCleanup(suiteName: "us.zig.zpod.swipe-uitests")
  super.tearDown()
}

// Solution 2: Reset app between critical tests
func testFreshState() {
  resetAppState(app: app)
  // Test with clean slate
}

// Solution 3: Verify cleanup in setUp
override func setUpWithError() throws {
  try super.setUpWithError()
  XCTAssertTrue(verifyUserDefaultsIsEmpty(suiteName: "us.zig.zpod.swipe-uitests"))
}
```

---

## Best Practices

### 1. Always Wait for Elements

Never assume elements exist immediately:

```swift
// ❌ NEVER do this
app.buttons["Submit"].tap()

// ✅ ALWAYS do this
let button = app.buttons["Submit"]
XCTAssertTrue(button.waitForExistence(timeout: 5.0))
button.tap()
```

### 2. Use Adaptive Timeouts in CI

The existing `UITestFoundation` protocol provides CI-aware timeouts:

```swift
// Uses 8s locally, 12s in CI
waitForElement(element, timeout: adaptiveTimeout, description: "Submit button")
```

### 3. Prefer Stability Over Speed

Don't rush interactions - wait for stability:

```swift
// ❌ Too fast - might fail
element.tap()

// ✅ Safe - waits for stability
element.waitForStable()
element.tap()
```

### 4. Clean Up in tearDown

Always clean up state to prevent pollution:

```swift
override func tearDown() {
  performStandardCleanup(suiteName: "us.zig.zpod.swipe-uitests")
  super.tearDown()
}
```

### 5. Use Descriptive Errors

Provide context when operations fail:

```swift
try retryTap(
  on: app.buttons["Submit"],
  attempts: 3,
  description: "Submit button in checkout flow step 3"
)
```

### 6. Combine Techniques

Use multiple helpers together for robustness:

```swift
// Discover element with scrolling
XCTAssertTrue(element.discoverWithScrolling(in: scrollView, timeout: 5.0))

// Wait for animation to complete
XCTAssertTrue(element.waitForAnimationComplete())

// Tap with retry
try element.tapWithRetry(attempts: 3)
```

---

## Migration Checklist

When migrating existing tests to use new infrastructure:

- [ ] Add `performStandardCleanup()` to `tearDown()`
- [ ] Replace direct taps with `tapWithRetry()` or `waitForStable()`
- [ ] Add `waitForExistence()` before element interactions
- [ ] Use `discoverWithScrolling()` for off-screen elements
- [ ] Wrap flaky assertions in `retryAssertion()`
- [ ] Use `waitForTransition()` for navigation
- [ ] Verify no state pollution with `verifyUserDefaultsIsEmpty()`

---

## Testing the Infrastructure

To verify the infrastructure works correctly:

1. **Run flaky tests locally 100 times**:
   ```bash
   for i in {1..100}; do
     xcodebuild test -only-testing:SwipePresetSelectionTests/testPresetSelection || break
   done
   ```

2. **Monitor CI success rate** over 1 week

3. **Check cleanup effectiveness**:
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

## Files Reference

| File | Purpose | Key Helpers |
|------|---------|-------------|
| `UITestRetryHelpers.swift` | Retry mechanisms | `retryOnFailure`, `tapWithRetry`, `retryElementDiscovery` |
| `UITestStableWaitHelpers.swift` | Stability waits | `waitForStable`, `waitForHittable`, `waitForTransition` |
| `UITestEnvironmentalIsolation.swift` | Cleanup | `performStandardCleanup`, `clearUserDefaults`, `clearKeychain` |
| `UITestImprovedElementDiscovery.swift` | Element finding | `discoverWithScrolling`, `waitWithRetry`, `findElementWithFallback` |

---

## Related Documentation

- [Test Flakiness Root Cause Analysis](../../dev-log/02.7.2-current-state-analysis.md)
- [Phase 3 Infrastructure Improvements](../../Issues/02.7.3-flakiness-infrastructure-improvements.md)
- [CI Flakiness Dashboard](./flakiness-dashboard.md)

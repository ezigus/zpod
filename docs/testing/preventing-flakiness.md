# Preventing Test Flakiness

**Created for**: Issue #148 (02.7.3 - CI Test Flakiness: Phase 3 - Infrastructure Improvements)
**Last Updated**: 2025-12-04 (Updated to match actual implementation)

## Overview

This guide documents the test infrastructure designed to prevent flaky test failures. The implementation follows a **deterministic, no-retry philosophy**: "UI elements appear immediately or not at all - if element isn't there, fix the root cause instead of retrying."

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

### 6. SwiftUI Lazy Unmaterialization - Critical Pattern

**⚠️ CRITICAL**: SwiftUI Lists use lazy rendering that **unmaterializes** elements when they scroll out of view, even if they were previously materialized. Pre-materialization does NOT keep elements accessible after scrolling away.

#### The Problem

SwiftUI's lazy rendering optimization removes elements from the accessibility tree when they're no longer visible:

```swift
// ❌ FAILS IN CI: Pre-materialize, scroll away, then try to interact
func testPresetSelection() {
  // 1. Open sheet (triggers pre-materialization)
  openConfigurationSheet()
  // → materializeSections() scrolls to bottom, then back to top

  // 2. Try to tap Download preset (at bottom of list)
  applyPreset("SwipeActions.Preset.Download")
  // ❌ FAILS: Download preset was unmaterialized when we scrolled to top!
}
```

**What Happens**:
1. `materializeSections()` scrolls to bottom of presets section → Download/Organization materialize
2. `materializeSections()` scrolls back to top → Download/Organization **unmaterialize** (out of view)
3. Test tries to tap Download preset → **Element doesn't exist** in accessibility tree

#### The Solution: Just-In-Time Scrolling

**Always scroll to element immediately before interaction**:

```swift
// ✅ WORKS: Scroll to element right before tapping
func applyPreset(identifier: String) {
  // 1. Scroll directly to target preset
  ensureVisibleInSheet(identifier: identifier, container: sheetContainer)

  // 2. Interact immediately while element is visible
  let presetButton = element(withIdentifier: identifier, within: sheetContainer)
  XCTAssertTrue(presetButton.waitForExistence(timeout: 2.0))
  presetButton.tap()
}
```

#### Bad vs Good Patterns

**❌ BAD: Rely on Pre-Materialization**
```swift
// Pre-materialize all sections
func openSheet() {
  materializeSections()  // Scrolls to bottom, then top
}

// Later: Try to interact with bottom element
func testDownloadPreset() {
  openSheet()  // Materialized, then unmaterialized Download preset
  tapPreset("Download")  // ❌ FAILS: Element no longer exists
}
```

**✅ GOOD: Just-In-Time Scrolling**
```swift
// Optional pre-materialization for performance
func openSheet() {
  materializeSections()  // Pre-load for faster initial render
}

// Always scroll to element before interaction
func tapPreset(_ presetID: String) {
  ensureVisibleInSheet(identifier: presetID, container: sheet)  // Scroll to it
  let button = element(withIdentifier: presetID, within: sheet)
  button.tap()  // ✅ SUCCESS: Element is visible and materialized
}
```

#### When This Pattern Applies

Use just-in-time scrolling for:
- ✅ Elements in scrollable lists that aren't initially visible
- ✅ Any element that could be off-screen after navigation/scrolling
- ✅ Bottom sections of sheets/modals that get scrolled past

**Real-World Example**: SwipePresetSelection tests
- Playback preset (2nd in list) → Visible after scroll-to-top → ✅ Works
- Download preset (4th in list) → Not visible after scroll-to-top → ❌ Fails without just-in-time scroll

#### Best Practices

```swift
// Pattern 1: Scroll before every interaction with potentially off-screen elements
func interact(with elementID: String, in container: XCUIElement) {
  // Ensure element is visible
  ensureVisibleInSheet(identifier: elementID, container: container)

  // Interact immediately
  let element = element(withIdentifier: elementID, within: container)
  XCTAssertTrue(element.waitForExistence(timeout: 2.0))
  element.tap()
}

// Pattern 2: Use ScrollViewReader in app code for reliable preset access
func applyPresetDirectly(presetID: String, proxy: ScrollViewProxy) {
  // Scroll directly to preset using SwiftUI
  withAnimation {
    proxy.scrollTo(presetID, anchor: .center)
  }

  // Element is guaranteed to be visible and materialized
}

// Pattern 3: Don't scroll back to top after materialization
func materializeSections(proxy: ScrollViewProxy) async {
  // Scroll through sections to materialize
  proxy.scrollTo("section-bottom", anchor: .bottom)

  // ❌ DON'T: proxy.scrollTo("top", anchor: .top)  // Unmaterializes bottom elements
  // ✅ DO: Leave scroll position where elements stay materialized
}
```

#### Debugging Tips

If elements unexpectedly don't exist:
1. Check if element requires scrolling to be visible
2. Verify you're scrolling to element before interacting
3. Confirm element wasn't unmaterialized by scrolling away
4. Use `reportAvailableSwipeIdentifiers()` to see what exists in accessibility tree

**See Also**:
- SwipePresetSelectionTests (reference implementation)
- dev-log/02.6.3-swipe-configuration-test-decomposition.md (root cause analysis)
- AGENTS.md § SwiftUI-Specific Considerations

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

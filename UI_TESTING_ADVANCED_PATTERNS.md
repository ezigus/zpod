# iOS UI Testing Best Practices - Advanced Patterns

This document supplements `AGENTS.md` with advanced UI testing patterns discovered from community best practices that go beyond Apple's official guidance.

## Source Attribution

Primary source: [Joe Masilotti's UI Testing Cheat Sheet](https://masilotti.com/ui-testing-cheat-sheet/)

## Advanced Patterns Not in Apple Docs

### 1. Screen Object Pattern (Page Object Model)

**Problem**: Test code becomes duplicated and brittle when UI changes

**Solution**: Encapsulate screen interactions in dedicated objects

```swift
class LoginScreen {
    private let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // Element queries
    private var usernameField: XCUIElement {
        app.textFields["Username"]
    }
    
    private var passwordField: XCUIElement {
        app.secureTextFields["Password"]
    }
    
    private var loginButton: XCUIElement {
        app.buttons["Login"]
    }
    
    // Actions
    func login(username: String, password: String) {
        usernameField.tap()
        usernameField.typeText(username)
        
        passwordField.tap()
        passwordField.typeText(password)
        
        loginButton.tap()
    }
    
    // Assertions
    func assertIsDisplayed() {
        XCTAssertTrue(loginButton.waitForExistence(timeout: 2))
    }
}

// Usage in test
func testLogin() {
    let loginScreen = LoginScreen(app: app)
    loginScreen.assertIsDisplayed()
    loginScreen.login(username: "test@example.com", password: "password")
    // Continue with next screen...
}
```

**Benefits**:
- Single source of truth for screen elements
- Easy to update when UI changes
- More readable tests
- Reusable across multiple tests

### 2. Robot Pattern

**Problem**: Screen Objects can become bloated with both UI interactions and assertions

**Solution**: Separate navigation/actions (Robot) from assertions (Screen Objects)

```swift
class LoginRobot {
    private let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    @discardableResult
    func enterUsername(_ username: String) -> Self {
        app.textFields["Username"].tap()
        app.textFields["Username"].typeText(username)
        return self
    }
    
    @discardableResult
    func enterPassword(_ password: String) -> Self {
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText(password)
        return self
    }
    
    @discardableResult
    func tapLogin() -> HomeRobot {
        app.buttons["Login"].tap()
        return HomeRobot(app: app)
    }
}

// Usage - fluent chaining
func testLogin() {
    LoginRobot(app: app)
        .enterUsername("test@example.com")
        .enterPassword("password")
        .tapLogin()
        .assertHomeScreenDisplayed()
}
```

**Benefits**:
- Fluent, readable test syntax
- Clear separation between actions and assertions
- Natural flow mimicking user journeys
- Type-safe navigation between screens

### 3. Verifying Elements Are Actually Visible

**Problem**: `exists` returns true even if element is off-screen

**Solution**: Check if element's frame is within the window's visible bounds

```swift
extension XCUIElement {
    var isFullyVisible: Bool {
        guard exists, !frame.isEmpty else { return false }
        let window = XCUIApplication().windows.element(boundBy: 0)
        return window.frame.contains(frame)
    }
}

// Usage
XCTAssertTrue(app.buttons["Submit"].isFullyVisible)
```

**Why This Matters**:
- Catches issues where elements exist but are scrolled off-screen
- Validates actual user-visible state
- Prevents false positives in tests

### 4. Complex Gesture Handling

#### Pull-to-Refresh Pattern

```swift
func pullToRefresh(on table: XCUIElement) {
    let firstCell = table.cells.firstMatch
    let start = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
    let finish = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 6))
    start.press(forDuration: 0, thenDragTo: finish)
}
```

#### Cell Reordering

```swift
func reorderCell(from: String, to: String) {
    let fromButton = app.buttons["Reorder \(from)"]
    let toButton = app.buttons["Reorder \(to)"]
    fromButton.press(forDuration: 0.5, thenDragTo: toButton)
}
```

**Key Insight**: Use `XCUICoordinate` API for precise gesture control not available through standard element methods

### 5. System Alert Handling Pattern

**Problem**: System permission dialogs block test execution

**Solution**: Set up interruption monitors before triggering the alert

```swift
func handleLocationPermissionAlert() {
    addUIInterruptionMonitor(withDescription: "Location Dialog") { alert in
        alert.buttons["Allow"].tap()
        return true
    }
    
    // Trigger the alert
    app.buttons["Enable Location"].tap()
    
    // CRITICAL: Must interact with app for handler to fire
    app.tap()
    
    // Verify permission granted
    XCTAssertTrue(app.staticTexts["Authorized"].exists)
}
```

**Why the `app.tap()` is needed**: Interruption monitors only fire when you interact with the app after the alert appears

### 6. Debugging with Accessibility Hierarchy

**Problem**: Hard to understand why element queries fail

**Solution**: Print the entire accessibility tree

```swift
override func setUpWithError() throws {
    try super.setUpWithError()
    
    // Print accessibility hierarchy when tests fail
    continueAfterFailure = false
    
    app.launch()
    
    // Debug helper
    print("=== ACCESSIBILITY HIERARCHY ===")
    print(app.debugDescription)
    print("==============================")
}
```

**When to Use**:
- Element queries mysteriously fail
- Need to understand available accessibility identifiers
- Debugging complex view hierarchies
- Validating accessibility setup

### 7. Picker Interaction Patterns

#### Single-Wheel Picker

```swift
app.pickerWheels.element.adjust(toPickerWheelValue: "Option 3")
```

#### Multi-Wheel Picker

```swift
// Add accessibility hints to your picker delegate
extension MyViewController: UIPickerViewAccessibilityDelegate {
    func pickerView(_ pickerView: UIPickerView, 
                    accessibilityHintForComponent component: Int) -> String? {
        return component == 0 ? "Hours" : "Minutes"
    }
}

// In tests - use predicates to handle compound labels
let hoursPredicate = NSPredicate(format: "label BEGINSWITH 'Hours'")
let hoursPicker = app.pickerWheels.element(matching: hoursPredicate)
hoursPicker.adjust(toPickerWheelValue: "10")
```

### 8. Slider Normalization Pattern

**Problem**: Slider values must be normalized 0.0-1.0, not actual values

**Solution**: Create helper that converts actual value to normalized position

```swift
extension XCUIElement {
    func adjustSlider(to value: Double, min: Double, max: Double) {
        let normalizedValue = (value - min) / (max - min)
        adjust(toNormalizedSliderPosition: normalizedValue)
    }
}

// Usage - set slider with range 0-100 to value 75
app.sliders.element.adjustSlider(to: 75, min: 0, max: 100)
```

## Test Organization Best Practices

### 1. Given-When-Then Structure

Always structure tests in three clear phases:

```swift
func testAddingItemToCart() {
    // Given - Set up initial state
    let product = "Book"
    XCTAssertEqual(cart.itemCount, 0)
    
    // When - Perform the action being tested
    addProductToCart(product)
    
    // Then - Verify the expected outcome
    XCTAssertEqual(cart.itemCount, 1)
    XCTAssertTrue(cart.contains(product))
}
```

### 2. Setup and Teardown Patterns

```swift
class CheckoutUITests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"] // Configure app for testing
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
}
```

### 3. Launch Arguments for Test Configuration

```swift
// In test
app.launchArguments = ["enable-testing", "mock-network"]
app.launch()

// In app
#if DEBUG
if CommandLine.arguments.contains("enable-testing") {
    // Disable animations
    UIView.setAnimationsEnabled(false)
    
    // Use mock data
    if CommandLine.arguments.contains("mock-network") {
        NetworkManager.shared.useMockData = true
    }
}
#endif
```

## Anti-Patterns to Avoid

### ❌ Don't Use Index-Based Queries

```swift
// BAD - brittle, breaks if order changes
app.buttons.element(boundBy: 0).tap()

// GOOD - specific and maintainable
app.buttons["Submit"].tap()
```

### ❌ Don't Rely on Recording Alone

**Why**:
- Recording doesn't teach you the APIs
- Breaks with custom controls
- Hard to debug generated code
- Doesn't work for web views, some complex UI

**When Recording is OK**:
- Quick regression tests on existing code
- Learning element structure
- Discovering accessibility identifiers

### ❌ Don't Skip Accessibility Identifiers

```swift
// BAD - using display text (changes with localization)
app.buttons["Submit Order"].tap()

// GOOD - using stable identifier
// In code: button.accessibilityIdentifier = "submit_order_button"
app.buttons["submit_order_button"].tap()
```

### ❌ Don't Use Fixed Delays Unless Absolutely Necessary

```swift
// BAD - slow and unreliable
app.buttons["Load Data"].tap()
sleep(5) // Hope this is long enough...

// GOOD - wait for specific condition
app.buttons["Load Data"].tap()
XCTAssertTrue(app.staticTexts["Data Loaded"].waitForExistence(timeout: 10))
```

## Key Takeaways Beyond Apple's Documentation

1. **Architectural Patterns**: Screen Objects and Robot patterns not mentioned in Apple docs but widely adopted in industry
2. **Visibility Checking**: `exists` isn't enough - need to verify elements are actually on-screen
3. **Gesture Precision**: `XCUICoordinate` for complex gestures (pull-to-refresh, custom swipes)
4. **System Alerts**: Specific pattern with interruption monitors + interaction requirement
5. **Debugging Tools**: Accessibility hierarchy printing invaluable for troubleshooting
6. **Test Organization**: Given-When-Then + Screen Objects makes tests maintainable at scale
7. **Configuration**: Launch arguments for test-specific app behavior
8. **Real Visibility**: Check frame containment, not just existence

## Additional Resources

- **Joe Masilotti's Cheat Sheet**: <https://masilotti.com/ui-testing-cheat-sheet/> (primary source)
- **Swift by Sundell - Unit Testing**: <https://www.swiftbysundell.com/basics/unit-testing/>
- Community forums and blogs for emerging patterns

---

**Note**: Always review this document alongside `AGENTS.md` Section 3 "iOS UI Testing Best Practices" when building or updating UI tests. The two documents are complementary - `AGENTS.md` covers the FIRST principles and Apple's official guidance, while this document covers advanced community patterns.

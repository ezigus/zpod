# UI Test Summary

This document outlines the UI testing approach for the main zpod application.

## Test Categories

### Core UI Navigation Tests (`CoreUINavigationTests.swift`)
**Purpose**: Verify main navigation flows and accessibility compliance

**Specifications Covered**:
- `spec/ui.md` - Navigating with CarPlay Layout
- `spec/ui.md` - Leveraging Accessibility Options  
- `spec/ui.md` - Optimizing for iPad UI
- `spec/ui.md` - Using App Shortcuts (iOS Quick Actions)

**Test Areas**:
- Main tab bar navigation
- Navigation stack management
- Accessibility labels and behaviors
- VoiceOver navigation flow
- iPad-specific layout adaptations
- Quick action handling
- Settings tab visibility and registry-backed feature navigation

### Playback UI Tests (`PlaybackUITests.swift`)
**Purpose**: Verify playback interface controls and platform integrations

**Specifications Covered**:
- `spec/ui.md` - Using Lock Screen and Control Center Players
- `spec/ui.md` - Controlling Playback via Headphones/Bluetooth
- `spec/ui.md` - Navigating with CarPlay Layout
- `spec/ui.md` - Apple Watch Support
- `spec/playback.md` - Player interface scenarios

**Test Areas**:
- Now playing screen controls
- Lock screen media controls
- Control center integration
- CarPlay player interface
- Apple Watch playback controls
- Bluetooth control handling

### Content Discovery UI Tests (`ContentDiscoveryUITests.swift`)
**Purpose**: Verify search, browse, and discovery interface functionality

**Specifications Covered**:
- `spec/ui.md` - Voice Control for Search (Siri Integration)
- `spec/discovery.md` - Search and browse scenarios
- `spec/content.md` - Content browsing interfaces

**Test Areas**:
- Search interface and results display
- Browse and category navigation
- Subscription management UI
- Filter and sort controls
- Content recommendation displays

### Swipe Configuration UI Tests (`SwipeConfigurationUITests.swift`)
**Purpose**: Validate the configurable swipe gesture workflow and ensure presets, haptics, and episode list actions remain stable.

**Specifications Covered**:
- `Issues/02.1-episode-list-management-ui.md` — Scenario 6: Swipe Gestures & Quick Actions
- `spec/ui.md` — Customizing Swipe Gestures section

**Test Areas**:
- Configuring leading/trailing swipe actions via presets and custom toggles
- Persisting haptic feedback settings and verifying style selection across launches
- Exercising configured swipe buttons within `EpisodeListView`, including playlist selection flows
- Accessibility identifier coverage for configuration controls and rendered swipe buttons
- Validates that preset buttons respond directly under automation (no manual fallback) and enforces the three-action cap via the add-action picker sheet

### Widget and Extension Tests (`WidgetExtensionTests.swift`)
**Purpose**: Verify home screen widgets and app extensions

**Specifications Covered**:
- `spec/ui.md` - Using Home Screen Widgets (iOS Widgets)
- `spec/ui.md` - Notification Actions
- `spec/ui.md` - Siri and Shortcuts Integration

**Test Areas**:
- Widget display and updates
- Widget interaction handling
- Notification action responses
- Siri shortcuts execution
- Extension activation

## UI Testing Framework

### Test Structure
- All UI tests use XCUIApplication for app launch and interaction
- Tests follow Given/When/Then structure with clear comments
- Each test is isolated and can run independently

### Event-Driven Waiting Pattern
- Uses XCUITest's native `waitForExistence()` and XCTestExpectation patterns
- No artificial `Thread.sleep()` or polling - responds to actual UI events
- Timeout = Failure: tests fail immediately when elements don't appear within timeout
- Helper functions: `waitForElement()`, `waitForAnyElement()`, `waitForLoadingToComplete()`

### Adaptive Timeout Scaling (Issue 12.7)
- **Timeout Scale Factor**: Controlled via `UITEST_TIMEOUT_SCALE` environment variable
  - Local default: 1.0 (no scaling)
  - CI default: 1.5 (50% longer timeouts for hosted runners)
  - Custom: Set `UITEST_TIMEOUT_SCALE=2.0` for slower environments
- **Base Timeouts**:
  - `adaptiveTimeout`: 10s local → 30s CI (20s base × 1.5 scale)
  - `adaptiveShortTimeout`: 5s local → 15s CI (10s base × 1.5 scale)
- **CI Diagnostics**: On timeout, helpers emit `app.debugDescription` to show accessibility tree
  - Helps debug failures without manual reproduction
  - Only active in CI to avoid local log noise

### Accessibility Testing
- All UI tests include accessibility verification
- VoiceOver labels and hints are validated
- Keyboard navigation is tested where applicable
- Color contrast and sizing compliance is verified

### Platform-Specific Testing
- iPhone-specific behaviors are tested on iPhone simulators
- iPad adaptations are tested on iPad simulators
- CarPlay integration is tested using CarPlay simulator
- Apple Watch behaviors are tested using paired watch simulator

### Test Data and State Management
- UI tests use consistent test data and app state
- Tests reset app state before execution
- Mock services are configured for reliable testing
- External dependencies are isolated

### Performance and Reliability
- Launch performance is measured and validated
- UI responsiveness is tested under load
- Memory usage during UI operations is monitored
- Battery impact of UI operations is considered

## Test Execution

### Automation
- All UI tests run in CI/CD pipeline
- Tests execute on multiple device configurations
- Screenshot capture on test failures
- Video recording for complex interaction flows

### Manual Testing Guidelines
- Manual testing supplements automated UI tests
- Focus on subjective user experience aspects
- Validation of animations and transitions
- Real device testing for platform-specific features

## Coverage Metrics

### User Journey Coverage
- Complete user workflows are tested end-to-end
- Critical paths receive priority testing attention
- Edge cases and error scenarios are included

### Interface Element Coverage
- All interactive elements are tested
- Navigation patterns are validated
- Form inputs and validation are verified
- Media controls and feedback are tested

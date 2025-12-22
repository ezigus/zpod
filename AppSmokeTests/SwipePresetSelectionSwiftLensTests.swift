#if false
// TODO: Re-enable when SwiftLens supports Swift 6.2+ strict concurrency
// Issue: Swift 6.2.3 (Xcode 26.2) has stricter concurrency checking that detects
// data race risks in SwiftLens's observer/interactor isolation model.
// CI (Swift 6.1.2) passes fine, but local builds fail with:
//   "error: sending 'workbench.observer' risks causing data races"
// 
// Tracked in: https://github.com/gahntpo/SwiftLens - pending Swift 6.2 compatibility
// Related: Issue 02.1.6.6, PR #163
//
// When re-enabling:
// 1. Verify SwiftLens has updated isolation annotations
// 2. Test locally on Swift 6.2.3+
// 3. Remove this #if false guard
//
#if os(iOS)
//
//  SwipePresetSelectionSwiftLensTests.swift
//  AppSmokeTests
//
//  Created for Issue 162 (02.1.6.6): SwiftLens Swipe UI Test Coverage
//  Pure SwiftLens unit tests for swipe preset selection
//
//  MIGRATION STATUS: 🆕 NEW (Pure SwiftLens Implementation)
//  - Purpose: Fast, reliable preset selection tests using SwiftLens
//  - Approach: In-process view testing (no XCUITest, no UI automation)
//  - Success Metric: 100% pass rate, <1s execution time per test
//
//  SwiftLens Library: https://github.com/gahntpo/SwiftLens
//  This is the SwiftUI testing library, not the SwiftLens MCP server.
//

#if canImport(SwiftUI) && canImport(SwiftLensTestSupport)
import XCTest
import SwiftUI
import SwiftLensTestSupport
@testable import LibraryFeature
import CoreModels
import SettingsDomain

/// Pure SwiftLens tests for swipe action preset selection
///
/// APPROACH: These tests instantiate SwipeActionConfigurationView directly
/// and use SwiftLens observers/interactors to test view behavior without
/// UI automation. This eliminates XCUITest timing issues entirely.
///
/// Key Advantages:
/// - ✅ No process boundary (runs in-process with the view)
/// - ✅ No accessibility tree dependency (direct state observation)
/// - ✅ No timing issues (observer-based, not polling)
/// - ✅ Fast execution (<1s per test vs 30s+ for XCUITest)
/// - ✅ 100% reliable (no flakiness from SwiftUI lazy rendering)
///
/// Limitations:
/// - ❌ Not end-to-end (doesn't test navigation, persistence)
/// - ❌ Requires mock repository (not using real persistence)
/// - ❌ Complements (doesn't replace) XCUITest end-to-end tests
///
@MainActor
final class SwipePresetSelectionSwiftLensTests: XCTestCase {

  // MARK: - Test Fixtures

  nonisolated(unsafe) private var mockService: MockSwipeConfigurationService!
  nonisolated(unsafe) private var controller: SwipeConfigurationController!

  // MARK: - Setup & Teardown

  override func setUpWithError() throws {
    try super.setUpWithError()
    continueAfterFailure = false
  }

  @MainActor
  override func setUp() async throws {
    // Create mock service with default configuration
    mockService = MockSwipeConfigurationService()
    controller = SwipeConfigurationController(service: mockService)
  }

  @MainActor
  override func tearDown() async throws {
    controller = nil
    mockService = nil
  }

  // MARK: - Preset Selection Tests (Pure SwiftLens)

  @MainActor
  func testDownloadPresetAppliesCorrectly_SwiftLens() async throws {
    // GIVEN: SwipeActionConfigurationView with default configuration
    // WHEN: User taps the "Download" preset button
    // THEN: Configuration updates to Download preset actions
    //
    // Spec: Issue #02.6.3 - Preset Selection Test 3 (SwiftLens implementation)

    // Load baseline configuration
    await controller.loadBaseline()

    // Create SwiftLens workbench wrapping the view
    let testController = controller!  // Local reference to avoid data races
    let workbench = LensWorkBench { _ in
      SwipeActionConfigurationView(controller: testController)
    }

    // Wait for Download preset button to be visible
    try await workbench.observer.waitForViewVisible(
      withID: "SwipeActions.Preset.Download",
      timeout: 2.0
    )

    // Tap the Download preset button
    try await workbench.interactor.tapButton(withID: "SwipeActions.Preset.Download")

    // Give the view a moment to update (SwiftUI state propagation)
    try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

    // Verify configuration changed to Download preset
    XCTAssertEqual(
      controller.leadingActions,
      [.download, .markPlayed],
      "Leading actions should be Download + Mark Played"
    )
    XCTAssertEqual(
      controller.trailingActions,
      [.archive, .delete],
      "Trailing actions should be Archive + Delete"
    )

    // Verify hasUnsavedChanges is true (preset changed configuration)
    XCTAssertTrue(
      controller.hasUnsavedChanges,
      "Controller should have unsaved changes after preset selection"
    )
  }

  @MainActor
  func testPlaybackPresetAppliesCorrectly_SwiftLens() async throws {
    // GIVEN: SwipeActionConfigurationView with default configuration
    // WHEN: User taps the "Playback" preset button
    // THEN: Configuration updates to Playback preset actions

    await controller.loadBaseline()

    let testController = controller!
    let workbench = LensWorkBench { _ in
      SwipeActionConfigurationView(controller: testController)
    }

    try await workbench.observer.waitForViewVisible(
      withID: "SwipeActions.Preset.Playback",
      timeout: 2.0
    )

    try await workbench.interactor.tapButton(withID: "SwipeActions.Preset.Playback")
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(
      controller.leadingActions,
      [.play, .addToPlaylist],
      "Leading actions should be Play + Add to Playlist"
    )
    XCTAssertEqual(
      controller.trailingActions,
      [.download, .favorite],
      "Trailing actions should be Download + Favorite"
    )
    XCTAssertTrue(controller.hasUnsavedChanges)
  }

  @MainActor
  func testOrganizationPresetAppliesCorrectly_SwiftLens() async throws {
    // GIVEN: SwipeActionConfigurationView with default configuration
    // WHEN: User taps the "Organization" preset button
    // THEN: Configuration updates to Organization preset actions

    await controller.loadBaseline()

    let testController = controller!
    let workbench = LensWorkBench { _ in
      SwipeActionConfigurationView(controller: testController)
    }

    try await workbench.observer.waitForViewVisible(
      withID: "SwipeActions.Preset.Organization",
      timeout: 2.0
    )

    try await workbench.interactor.tapButton(withID: "SwipeActions.Preset.Organization")
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(
      controller.leadingActions,
      [.markPlayed, .favorite],
      "Leading actions should be Mark Played + Favorite"
    )
    XCTAssertEqual(
      controller.trailingActions,
      [.archive, .delete],
      "Trailing actions should be Archive + Delete"
    )
    XCTAssertTrue(controller.hasUnsavedChanges)
  }

  @MainActor
  func testSaveButtonEnablesAfterPresetSelection_SwiftLens() async throws {
    // GIVEN: SwipeActionConfigurationView with baseline loaded
    // WHEN: User selects any preset
    // THEN: Save button becomes enabled (hasUnsavedChanges = true)

    await controller.loadBaseline()

    // Initially, no unsaved changes
    XCTAssertFalse(controller.hasUnsavedChanges, "Should have no unsaved changes initially")

    let testController = controller!
    let workbench = LensWorkBench { _ in
      SwipeActionConfigurationView(controller: testController)
    }

    // Select Download preset
    try await workbench.observer.waitForViewVisible(
      withID: "SwipeActions.Preset.Download",
      timeout: 2.0
    )

    try await workbench.interactor.tapButton(withID: "SwipeActions.Preset.Download")
    try await Task.sleep(nanoseconds: 100_000_000)

    // Save button should be enabled
    XCTAssertTrue(
      controller.hasUnsavedChanges,
      "Save button should be enabled after preset selection"
    )
  }
}

// MARK: - Mock Service

/// Mock service for SwiftLens testing
/// Returns default configuration for all operations
private actor MockSwipeConfigurationService: SwipeConfigurationServicing {

  private var currentConfiguration: SwipeConfiguration = .default
  private let continuation: AsyncStream<SwipeConfiguration>.Continuation

  init() {
    let (stream, continuation) = AsyncStream<SwipeConfiguration>.makeStream()
    self.continuation = continuation
  }

  func load() async -> SwipeConfiguration {
    return currentConfiguration
  }

  func save(_ configuration: SwipeConfiguration) async throws {
    currentConfiguration = configuration
    continuation.yield(configuration)
  }

  nonisolated func updatesStream() -> AsyncStream<SwipeConfiguration> {
    return AsyncStream { continuation in
      // No-op for testing
    }
  }
}

#endif
#endif  // canImport(SwiftUI) && canImport(SwiftLensTestSupport)
#endif  // os(iOS)

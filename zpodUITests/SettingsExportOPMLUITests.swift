//
//  SettingsExportOPMLUITests.swift
//  zpodUITests
//
//  UI tests for the Export Subscriptions (OPML) button in Settings (Issue #450).
//
//  Spec coverage (Given/When/Then):
//    AC1 — Export button is present and tappable in Settings "Data & Subscriptions"
//    AC2 — "Export Failed" alert shown when library contains no subscriptions
//    AC1 — Tapping the button with subscriptions present triggers the file exporter sheet
//
//  Test Pyramid Breakdown:
//  - 3 UI (E2E) tests covering button visibility, success path, and empty-library error path
//  - Unit layer covered by OPMLExportServiceTests (7 tests in FeedParsing package)

import XCTest

/// UI tests for the Export Subscriptions (OPML) feature in Settings.
///
/// Note on seeding: `launchConfiguredApp()` sets `UITEST_SEED_PODCASTS=1` by default,
/// which seeds a subscribed "Swift Talk" podcast. Tests that need an empty library must
/// override with `UITEST_SEED_PODCASTS=0`.
final class SettingsExportOPMLUITests: IsolatedUITestCase {

  // MARK: - AC1: Button is visible and tappable

  /// Given: The user is on the Settings screen
  /// When: The "Data & Subscriptions" section is visible
  /// Then: The "Export Subscriptions (OPML)" button exists and is hittable
  ///
  /// **AC1** — button presence in Settings
  @MainActor
  func testExportOPMLButton_isVisibleInSettings() throws {
    app = launchConfiguredApp()

    let tabs = TabBarNavigation(app: app)
    XCTAssertTrue(tabs.navigateToSettings(), "Should navigate to Settings tab")

    // The "Data & Subscriptions" section is the second section — visible without scrolling
    let button = app.buttons.matching(identifier: "Settings.ExportOPML").firstMatch

    XCTAssertTrue(
      button.waitForExistence(timeout: adaptiveTimeout),
      "Export Subscriptions (OPML) button should be present in the Data & Subscriptions section"
    )
    XCTAssertTrue(button.isHittable, "Export button should be tappable")
  }

  // MARK: - AC1: File exporter sheet appears when subscriptions exist

  /// Given: The user is on the Settings screen and has subscriptions (seeded by default)
  /// When: The "Export Subscriptions (OPML)" button is tapped
  /// Then: A file exporter sheet appears (the system document picker / save dialog)
  ///
  /// **AC1** — success path: file exporter triggered
  @MainActor
  func testExportOPMLButton_withSubscriptions_presentsFileSaverSheet() throws {
    // Default launch seeds a subscribed podcast (UITEST_SEED_PODCASTS=1)
    app = launchConfiguredApp()

    let tabs = TabBarNavigation(app: app)
    XCTAssertTrue(tabs.navigateToSettings(), "Should navigate to Settings tab")

    let settings = SettingsScreen(app: app)
    XCTAssertTrue(settings.tapExportOPML(), "Should tap the Export Subscriptions (OPML) button")

    // The .fileExporter modifier presents a UIDocumentPickerViewController.
    // iOS rendering varies: presents as a UISheetPresentationController (device/some simulators),
    // a navigation-based file browser (iOS 16-17 simulators), or a full-screen navigation
    // controller (iOS 18+ simulators). Three detection strategies cover all cases:
    //
    //   1. `app.sheets.firstMatch`        — sheet-style presentation
    //   2. `app.buttons["Cancel"]`        — system Cancel button (label-based, not identifier)
    //   3. `app.navigationBars.count > 1` — nav-based browser adds a second navigation bar
    //
    // Strategy 3 is reliable here because the Settings view has exactly one NavigationBar;
    // the file picker navigation controller always adds a second.
    let pickerSheet = app.sheets.firstMatch
    let cancelButton = app.buttons["Cancel"].firstMatch
    let navBarsBefore = app.navigationBars.count
    let sheetOrNav = pickerSheet.waitForExistence(timeout: adaptiveTimeout)
      || cancelButton.waitForExistence(timeout: adaptiveShortTimeout)
      || app.navigationBars.count > navBarsBefore

    XCTAssertTrue(
      sheetOrNav,
      "File exporter UI should appear (sheet or nav-based picker) after tapping Export when subscriptions exist"
    )
  }

  // MARK: - AC2: Empty library triggers alert

  /// Given: The user is on the Settings screen and has no subscriptions
  /// When: The "Export Subscriptions (OPML)" button is tapped
  /// Then: An "Export Failed" alert appears with a "no subscriptions" message
  ///
  /// **AC2** — no-subscriptions error surface
  @MainActor
  func testExportOPMLButton_emptyLibrary_showsExportFailedAlert() throws {
    // Suppress default podcast seeding so the library is empty.
    // Launch directly on the Settings tab to avoid the Library's empty-state rendering,
    // which can keep the app non-idle and block tab-bar interaction.
    app = launchConfiguredApp(environmentOverrides: [
      "UITEST_SEED_PODCASTS": "0",
      "UITEST_INITIAL_TAB": "settings",
    ])

    let tabs = TabBarNavigation(app: app)
    XCTAssertTrue(tabs.navigateToSettings(), "Should navigate to Settings tab")

    let settings = SettingsScreen(app: app)
    XCTAssertTrue(settings.tapExportOPML(), "Should tap the Export Subscriptions (OPML) button")

    // OPMLExportService throws .noSubscriptions → SettingsHomeView maps this to
    // the "Export Failed" alert with message "You have no subscriptions to export."
    let alert = app.alerts.firstMatch
    XCTAssertTrue(
      alert.waitForExistence(timeout: adaptiveTimeout),
      "Export Failed alert should appear when there are no subscriptions"
    )

    // Dismiss the alert
    let okButton = alert.buttons["OK"].firstMatch
    XCTAssertTrue(okButton.waitForExistence(timeout: adaptiveShortTimeout), "OK button should be present")
    okButton.tap()

    XCTAssertFalse(alert.exists, "Alert should be dismissed after tapping OK")
  }

}

//
//  PodcastCustomSettingsUITests.swift
//  zpodUITests
//
//  Tests for Issue #478: [06.5.1] PodcastCustomSettingsView scaffolding,
//  access points, and Reset All.
//
//  Spec scenarios covered:
//  - Given a podcast exists, long-pressing the card shows "Custom Settings…" in context menu
//  - Given a podcast exists, tapping the gear button in EpisodeListView opens custom settings
//  - Given the custom settings sheet is open, Reset All button is visible
//  - Given Reset confirmation dialog appears, cancelling dismisses it without changes
//  - Given Reset confirmation dialog appears, confirming it completes and dismisses the sheet
//

import TestSupport
import XCTest

final class PodcastCustomSettingsUITests: IsolatedUITestCase {

    // MARK: - Helpers

    @MainActor
    private func navigateToLibrary() {
        let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: adaptiveTimeout),
            "Main tab bar must exist before navigating to Library"
        )
        let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
        XCTAssertTrue(
            libraryTab.waitForExistence(timeout: adaptiveShortTimeout),
            "Library tab button must be discoverable"
        )
        libraryTab.tap()
    }

    @MainActor
    private func openCustomSettingsViaContextMenu() {
        let podcastCard = app.buttons
            .matching(identifier: "Podcast-\(PodcastFixtures.swiftTalk.id)")
            .firstMatch
        XCTAssertTrue(
            podcastCard.waitForExistence(timeout: adaptiveTimeout),
            "Podcast card must exist before long-pressing"
        )
        podcastCard.press(forDuration: 1.0)

        let menuItem = app.buttons
            .matching(identifier: "Podcast-\(PodcastFixtures.swiftTalk.id).CustomSettings")
            .firstMatch
        XCTAssertTrue(
            menuItem.waitForExistence(timeout: adaptiveTimeout),
            "Custom Settings context menu item must appear after long-press"
        )
        menuItem.tap()
    }

    @MainActor
    private func openCustomSettingsViaGearButton() {
        let podcastCard = app.buttons
            .matching(identifier: "Podcast-\(PodcastFixtures.swiftTalk.id)")
            .firstMatch
        XCTAssertTrue(
            podcastCard.waitForExistence(timeout: adaptiveTimeout),
            "Podcast card must exist"
        )
        podcastCard.tap()

        let gearButton = app.buttons
            .matching(identifier: "PodcastCustomSettingsButton")
            .firstMatch
        XCTAssertTrue(
            gearButton.waitForExistence(timeout: adaptiveTimeout),
            "Gear button must appear in podcast detail toolbar"
        )
        gearButton.tap()
    }

    @MainActor
    private func waitForCustomSettingsSheet() {
        let resetButton = app.buttons
            .matching(identifier: "PodcastCustomSettings.ResetButton")
            .firstMatch
        XCTAssertTrue(
            resetButton.waitForExistence(timeout: adaptiveTimeout),
            "PodcastCustomSettingsView Reset button must appear"
        )
    }

    // MARK: - Tests

    // MARK: Access Point: Context Menu

    /// Given: App launched with a seeded podcast
    /// When:  User long-presses the podcast card in Library
    /// Then:  "Custom Settings…" context menu item appears
    @MainActor
    func testContextMenuShowsCustomSettingsItem() throws {
        app = launchConfiguredApp()
        navigateToLibrary()

        let podcastCard = app.buttons
            .matching(identifier: "Podcast-\(PodcastFixtures.swiftTalk.id)")
            .firstMatch
        XCTAssertTrue(
            podcastCard.waitForExistence(timeout: adaptiveTimeout),
            "Podcast card must exist in Library"
        )
        podcastCard.press(forDuration: 1.0)

        let menuItem = app.buttons
            .matching(identifier: "Podcast-\(PodcastFixtures.swiftTalk.id).CustomSettings")
            .firstMatch
        XCTAssertTrue(
            menuItem.waitForExistence(timeout: adaptiveTimeout),
            "Custom Settings context menu item must appear after long-press on podcast card"
        )
    }

    /// Given: App launched with a seeded podcast
    /// When:  User long-presses podcast card and taps "Custom Settings…"
    /// Then:  PodcastCustomSettingsView opens with Reset button visible
    @MainActor
    func testContextMenuOpensCustomSettingsSheet() throws {
        app = launchConfiguredApp()
        navigateToLibrary()
        openCustomSettingsViaContextMenu()
        waitForCustomSettingsSheet()
    }

    // MARK: Access Point: Gear Button

    /// Given: App launched with a seeded podcast
    /// When:  User taps the podcast card then taps the gear button
    /// Then:  PodcastCustomSettingsView opens with Reset button visible
    @MainActor
    func testGearButtonOpensCustomSettingsSheet() throws {
        app = launchConfiguredApp()
        navigateToLibrary()
        openCustomSettingsViaGearButton()
        waitForCustomSettingsSheet()
    }

    // MARK: Reset All — Cancel Flow

    /// Given: PodcastCustomSettingsView is open (via context menu)
    /// When:  User taps "Reset to Global Defaults" then taps "Cancel"
    /// Then:  Confirmation dialog dismisses; settings sheet remains visible
    @MainActor
    func testResetCancelKeepsSheetOpen() throws {
        app = launchConfiguredApp()
        navigateToLibrary()
        openCustomSettingsViaContextMenu()
        waitForCustomSettingsSheet()

        let resetButton = app.buttons
            .matching(identifier: "PodcastCustomSettings.ResetButton")
            .firstMatch
        resetButton.tap()

        let cancelButton = app.alerts.buttons
            .matching(identifier: "PodcastCustomSettings.ResetCancelButton")
            .firstMatch
        XCTAssertTrue(
            cancelButton.waitForExistence(timeout: adaptiveTimeout),
            "Cancel button must appear in reset confirmation alert"
        )
        cancelButton.tap()

        // Sheet must remain open after cancel
        let resetButtonAfterCancel = app.buttons
            .matching(identifier: "PodcastCustomSettings.ResetButton")
            .firstMatch
        XCTAssertTrue(
            resetButtonAfterCancel.waitForExistence(timeout: adaptiveTimeout),
            "Custom settings sheet must remain visible after cancelling reset confirmation"
        )
    }

    // MARK: Reset All — Happy Path

    /// Given: PodcastCustomSettingsView is open (via gear button)
    /// When:  User taps "Reset to Global Defaults" then confirms
    /// Then:  Sheet dismisses (Reset completed successfully)
    @MainActor
    func testResetConfirmDismissesSheet() throws {
        app = launchConfiguredApp()
        navigateToLibrary()
        openCustomSettingsViaGearButton()
        waitForCustomSettingsSheet()

        let resetButton = app.buttons
            .matching(identifier: "PodcastCustomSettings.ResetButton")
            .firstMatch
        resetButton.tap()

        let confirmButton = app.alerts.buttons
            .matching(identifier: "PodcastCustomSettings.ResetConfirmButton")
            .firstMatch
        XCTAssertTrue(
            confirmButton.waitForExistence(timeout: adaptiveTimeout),
            "Reset confirm button must appear in confirmation alert"
        )
        confirmButton.tap()

        // After confirming reset, the sheet must dismiss — Reset button should disappear
        let resetButtonAfterConfirm = app.buttons
            .matching(identifier: "PodcastCustomSettings.ResetButton")
            .firstMatch
        let notExists = NSPredicate(format: "exists == false")
        let disappears = XCTNSPredicateExpectation(predicate: notExists, object: resetButtonAfterConfirm)
        wait(for: [disappears], timeout: adaptiveTimeout)
        XCTAssertFalse(
            resetButtonAfterConfirm.exists,
            "Custom settings sheet must dismiss after confirming reset"
        )
    }
}

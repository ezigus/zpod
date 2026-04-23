//
//  PodcastPriorityUITests.swift
//  zpodUITests
//
//  Tests for Issue #468: [06.2.1] Priority storage, UI, and download queue integration
//
//  Spec scenarios covered:
//  - Given a podcast exists, opening Custom Settings shows the Priority slider
//  - Given the priority slider is at default (0), the value label reads "0  Normal"
//  - Given priority is 0, no priority badge appears on the library card
//  - Given the slider is moved to a positive value, the value label updates immediately
//  - Given the slider is moved to a negative value, the value label updates immediately
//

import TestSupport
import XCTest

final class PodcastPriorityUITests: IsolatedUITestCase {

    // MARK: - Navigation Helpers

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
    private func waitForCustomSettingsSheet() {
        let resetButton = app.buttons
            .matching(identifier: "PodcastCustomSettings.ResetButton")
            .firstMatch
        XCTAssertTrue(
            resetButton.waitForExistence(timeout: adaptiveTimeout),
            "PodcastCustomSettingsView Reset button must appear"
        )
    }

    @MainActor
    private func dismissCustomSettingsSheet() {
        let doneButton = app.buttons
            .matching(identifier: "PodcastCustomSettings.DoneButton")
            .firstMatch
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: adaptiveTimeout),
            "Done button must be present to dismiss custom settings"
        )
        doneButton.tap()

        // Verify sheet dismissed
        let resetButton = app.buttons
            .matching(identifier: "PodcastCustomSettings.ResetButton")
            .firstMatch
        let notExists = NSPredicate(format: "exists == false")
        let disappears = XCTNSPredicateExpectation(predicate: notExists, object: resetButton)
        wait(for: [disappears], timeout: adaptiveTimeout)
    }

    // MARK: - Tests

    // MARK: Priority Slider Visibility

    /// Given: App launched with a seeded podcast
    /// When:  User opens Custom Settings via long-press context menu
    /// Then:  Priority slider and value label are visible in the settings sheet
    @MainActor
    func testPrioritySliderExistsInCustomSettings() throws {
        app = launchConfiguredApp()
        navigateToLibrary()
        openCustomSettingsViaContextMenu()
        waitForCustomSettingsSheet()

        let prioritySlider = app.sliders
            .matching(identifier: "PodcastCustomSettings.PrioritySlider")
            .firstMatch
        XCTAssertTrue(
            prioritySlider.waitForExistence(timeout: adaptiveTimeout),
            "Priority slider must be visible in the Custom Settings sheet"
        )

        let priorityLabel = app.staticTexts
            .matching(identifier: "PodcastCustomSettings.PriorityValueLabel")
            .firstMatch
        XCTAssertTrue(
            priorityLabel.waitForExistence(timeout: adaptiveShortTimeout),
            "Priority value label must be visible alongside the slider"
        )
    }

    // MARK: Default Priority Label

    /// Given: App launched with a seeded podcast (no custom priority set)
    /// When:  User opens Custom Settings
    /// Then:  Priority value label shows "0  Normal" (default priority is 0)
    @MainActor
    func testPriorityValueLabelDefaultsToNormal() throws {
        app = launchConfiguredApp()
        navigateToLibrary()
        openCustomSettingsViaContextMenu()
        waitForCustomSettingsSheet()

        let priorityLabel = app.staticTexts
            .matching(identifier: "PodcastCustomSettings.PriorityValueLabel")
            .firstMatch
        XCTAssertTrue(
            priorityLabel.waitForExistence(timeout: adaptiveTimeout),
            "Priority value label must be visible"
        )
        XCTAssertEqual(
            priorityLabel.label,
            "0  Normal",
            "Default priority value label must read '0  Normal'"
        )
    }

    // MARK: Priority Badge at Default Priority

    /// Given: App launched with a seeded podcast and default priority (0)
    /// When:  User views the Library
    /// Then:  No priority badge appears on the podcast card (badge only shows when priority ≠ 0)
    @MainActor
    func testNoPriorityBadgeAtDefaultPriority() throws {
        app = launchConfiguredApp()
        navigateToLibrary()

        // Verify the podcast card exists
        let podcastCard = app.buttons
            .matching(identifier: "Podcast-\(PodcastFixtures.swiftTalk.id)")
            .firstMatch
        XCTAssertTrue(
            podcastCard.waitForExistence(timeout: adaptiveTimeout),
            "Podcast card must exist in Library"
        )

        // Badge must NOT exist at default priority (0)
        let priorityBadge = app.staticTexts
            .matching(identifier: "Library.PriorityBadge")
            .firstMatch
        XCTAssertFalse(
            priorityBadge.exists,
            "Priority badge must not appear when download priority is 0 (default)"
        )
    }

    // MARK: Priority Label Updates on Slider Change

    /// Given: Custom Settings is open with default priority (0)
    /// When:  User moves the slider toward the positive end
    /// Then:  The value label updates to show a positive priority label
    @MainActor
    func testPriorityLabelUpdatesWhenSliderMovesToPositive() throws {
        app = launchConfiguredApp()
        navigateToLibrary()
        openCustomSettingsViaContextMenu()
        waitForCustomSettingsSheet()

        let prioritySlider = app.sliders
            .matching(identifier: "PodcastCustomSettings.PrioritySlider")
            .firstMatch
        XCTAssertTrue(
            prioritySlider.waitForExistence(timeout: adaptiveTimeout),
            "Priority slider must be visible before adjusting"
        )

        // Move slider to the high end (normalized 1.0 = +10)
        prioritySlider.adjust(toNormalizedSliderPosition: 1.0)

        let priorityLabel = app.staticTexts
            .matching(identifier: "PodcastCustomSettings.PriorityValueLabel")
            .firstMatch
        XCTAssertTrue(
            priorityLabel.waitForExistence(timeout: adaptiveShortTimeout),
            "Priority value label must remain visible after slider adjustment"
        )
        // Label should show a positive priority (not "0  Normal")
        XCTAssertTrue(
            priorityLabel.label.hasPrefix("+"),
            "Priority label must show a positive value (e.g. '+10  Prioritized') after moving slider to high end; got: '\(priorityLabel.label)'"
        )
    }

    /// Given: Custom Settings is open with default priority (0)
    /// When:  User moves the slider toward the negative end
    /// Then:  The value label updates to show a negative priority label
    @MainActor
    func testPriorityLabelUpdatesWhenSliderMovesToNegative() throws {
        app = launchConfiguredApp()
        navigateToLibrary()
        openCustomSettingsViaContextMenu()
        waitForCustomSettingsSheet()

        let prioritySlider = app.sliders
            .matching(identifier: "PodcastCustomSettings.PrioritySlider")
            .firstMatch
        XCTAssertTrue(
            prioritySlider.waitForExistence(timeout: adaptiveTimeout),
            "Priority slider must be visible before adjusting"
        )

        // Use press-then-drag to guarantee the slider claims the gesture over the sheet's
        // scroll view, which would otherwise intercept a plain leftward swipe.
        // Drag from center (value=0, normalized=0.5) to ~20% (value≈-6, clearly negative).
        let sliderCenter = prioritySlider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let sliderLeft   = prioritySlider.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        sliderCenter.press(forDuration: 0.05, thenDragTo: sliderLeft)

        let priorityLabel = app.staticTexts
            .matching(identifier: "PodcastCustomSettings.PriorityValueLabel")
            .firstMatch
        XCTAssertTrue(
            priorityLabel.waitForExistence(timeout: adaptiveShortTimeout),
            "Priority value label must remain visible after slider adjustment"
        )
        // Wait for SwiftUI to re-render with the new negative value before asserting.
        let negativeValuePredicate = NSPredicate(format: "label BEGINSWITH '-'")
        let labelUpdated = XCTNSPredicateExpectation(predicate: negativeValuePredicate, object: priorityLabel)
        let result = XCTWaiter.wait(for: [labelUpdated], timeout: adaptiveTimeout)
        XCTAssertEqual(
            result, .completed,
            "Priority label must show a negative value (e.g. '-10  Deprioritized') after moving slider to low end; got: '\(priorityLabel.label)'"
        )
    }
}

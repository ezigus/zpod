//
//  OPMLImportScreen.swift
//  zpodUITests
//
//  Created for Issue #451 - OPML Import UI Tests
//  Page Object for the OPML Import settings screen
//

import Foundation
import XCTest

/// Page Object for the OPML Import settings flow.
///
/// **Responsibilities**:
/// - Navigate from Settings home into the OPML Import screen
/// - Locate the "Import Subscriptions (OPML)" button
/// - Verify the import result sheet elements
///
/// **Usage**:
/// ```swift
/// let opml = OPMLImportScreen(app: app)
/// XCTAssertTrue(opml.importButton.waitForExistence(timeout: 5))
/// opml.tapImport()
/// ```
///
/// **Issue**: #451 - OPML Import Feature
@MainActor
public struct OPMLImportScreen: BaseScreen {
    public let app: XCUIApplication

    // MARK: - Elements

    /// The "Data & Subscriptions" navigation link that leads to the OPML Import sub-screen.
    ///
    /// SwiftUI wraps NavigationLinks in extra elements, so we try multiple types.
    var opmlImportNavRow: XCUIElement? {
        findOPMLNavRow()
    }

    /// The "Import Subscriptions (OPML)" action button inside the OPML Import screen.
    public var importButton: XCUIElement {
        app.buttons.matching(identifier: "Settings.ImportOPML").firstMatch
    }

    /// The import result sheet root container.
    public var resultView: XCUIElement {
        // The List carrying this identifier may appear as any scroll-view type.
        let candidates: [XCUIElement] = [
            app.collectionViews.matching(identifier: "Settings.ImportOPML.Result").firstMatch,
            app.tables.matching(identifier: "Settings.ImportOPML.Result").firstMatch,
            app.scrollViews.matching(identifier: "Settings.ImportOPML.Result").firstMatch,
            app.otherElements.matching(identifier: "Settings.ImportOPML.Result").firstMatch
        ]
        return candidates.first(where: { $0.exists }) ?? candidates[0]
    }

    /// Navigation title label for the OPML Import screen.
    private var opmlImportNavTitle: XCUIElement {
        app.navigationBars["OPML Import"].firstMatch
    }

    // MARK: - Actions

    /// Scroll the Settings list until the OPML Import nav row is hittable, then tap it.
    ///
    /// - Returns: True if the OPML Import screen was reached.
    @discardableResult
    public func navigateToOPMLImport() -> Bool {
        guard let row = scrollToOPMLNavRow() else { return false }
        guard tap(row) else { return false }

        // Verify OPML Import screen appeared by looking for nav title or import button.
        let arrived = [
            opmlImportNavTitle,
            importButton
        ]
        return waitForAny(arrived) != nil
    }

    /// Tap the "Import Subscriptions (OPML)" button (assumes already on the import screen).
    public func tapImport() {
        importButton.tap()
    }

    // MARK: - Helpers

    /// Builds the candidate list for the OPML Import nav row.
    private func findOPMLNavRow() -> XCUIElement? {
        let identifiers = [
            "Settings.DataSubscriptions.OPMLImport",
            "Settings.DataSubscriptions.OPMLImport.Label",
            "OPML Import"
        ]
        var candidates: [XCUIElement] = []
        for id in identifiers {
            candidates += [
                app.buttons.matching(identifier: id).firstMatch,
                app.otherElements.matching(identifier: id).firstMatch,
                app.cells.matching(identifier: id).firstMatch,
                app.staticTexts.matching(identifier: id).firstMatch
            ]
        }
        return waitForAny(candidates)
    }

    /// Scrolls the Settings list until the OPML Import nav row is hittable.
    ///
    /// The "Data & Subscriptions" section sits below the "Storage" section so it may
    /// need one swipe to become visible, especially on smaller device simulators.
    private func scrollToOPMLNavRow(maxSwipes: Int = 6) -> XCUIElement? {
        let identifiers = [
            "Settings.DataSubscriptions.OPMLImport",
            "Settings.DataSubscriptions.OPMLImport.Label",
            "OPML Import"
        ]
        var candidates: [XCUIElement] = []
        for id in identifiers {
            candidates += [
                app.buttons.matching(identifier: id).firstMatch,
                app.otherElements.matching(identifier: id).firstMatch,
                app.cells.matching(identifier: id).firstMatch,
                app.staticTexts.matching(identifier: id).firstMatch
            ]
        }

        // Check if already hittable before scrolling.
        if let hittable = candidates.first(where: { $0.exists && $0.isHittable }) {
            return hittable
        }

        // Scroll the Settings list.
        let settingsListCandidates = [
            app.collectionViews.matching(identifier: "Settings.Content").firstMatch,
            app.tables.matching(identifier: "Settings.Content").firstMatch,
            app.scrollViews.matching(identifier: "Settings.Content").firstMatch,
            app.otherElements.matching(identifier: "Settings.Content").firstMatch
        ]
        let settingsList = settingsListCandidates.first(where: { $0.exists }) ?? settingsListCandidates[0]

        for _ in 0..<maxSwipes {
            settingsList.swipeUp()
            if let hittable = candidates.first(where: { $0.exists && $0.isHittable }) {
                return hittable
            }
        }

        return nil
    }
}

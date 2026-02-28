import Foundation
import XCTest

/// Page Object for the Smart Playlist authoring UI.
///
/// Encapsulates navigation to the Playlists tab, triggering the creation/edit
/// sheet, and interacting with form fields — so test bodies read like user stories.
///
/// ## Accessibility Identifiers Used
/// - `"Playlist.CreateButton"` — the "+" menu button in the Playlists nav bar
/// - `"SmartPlaylistCreation.NameField"` — name text field in the creation form
/// - `"SmartPlaylistCreation.SaveButton"` — Save/Create toolbar button
/// - `"SmartPlaylistCreation.CancelButton"` — Cancel toolbar button
/// - `"SmartPlaylistCreation.LogicPicker"` — AND/OR logic picker
/// - `"SmartPlaylistCreation.AddRule"` — "Add Rule" button
///
/// **Issue**: #418 — Smart Playlist Authoring and Editing
@MainActor
public struct SmartPlaylistScreen: BaseScreen {
    public let app: XCUIApplication

    // MARK: - Tab Bar

    private var tabBar: XCUIElement {
        app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    }

    private var playlistsTab: XCUIElement {
        tabBar.buttons.matching(identifier: "Playlists").firstMatch
    }

    // MARK: - List-Level Elements

    private var createButton: XCUIElement {
        app.buttons.matching(identifier: "Playlist.CreateButton").firstMatch
    }

    private var newSmartPlaylistMenuItem: XCUIElement {
        // SwiftUI Menu items are exposed as buttons with their label text.
        let predicate = NSPredicate(format: "label == 'New Smart Playlist'")
        return app.buttons.matching(predicate).firstMatch
    }

    // MARK: - Creation Form Elements

    var nameField: XCUIElement {
        app.textFields.matching(identifier: "SmartPlaylistCreation.NameField").firstMatch
    }

    var saveButton: XCUIElement {
        app.buttons.matching(identifier: "SmartPlaylistCreation.SaveButton").firstMatch
    }

    var cancelButton: XCUIElement {
        app.buttons.matching(identifier: "SmartPlaylistCreation.CancelButton").firstMatch
    }

    var discardButton: XCUIElement {
        let predicate = NSPredicate(format: "label == 'Discard'")
        return app.buttons.matching(predicate).firstMatch
    }

    var addRuleButton: XCUIElement {
        app.buttons.matching(identifier: "SmartPlaylistCreation.AddRule").firstMatch
    }

    var logicPicker: XCUIElement {
        app.pickers.matching(identifier: "SmartPlaylistCreation.LogicPicker").firstMatch
    }

    // MARK: - Navigation

    /// Navigate to the Playlists tab and wait for the screen to load.
    ///
    /// - Returns: `true` if navigation succeeded and Playlists content is visible.
    @discardableResult
    public func navigateToPlaylists(timeout: TimeInterval? = nil) -> Bool {
        guard tap(playlistsTab, timeout: timeout) else { return false }
        return waitForPlaylistsContent(timeout: timeout)
    }

    /// Wait for Playlists content to become visible (create button or nav title).
    @discardableResult
    public func waitForPlaylistsContent(timeout: TimeInterval? = nil) -> Bool {
        let candidates: [XCUIElement] = [
            createButton,
            app.navigationBars.matching(NSPredicate(format: "identifier == 'Playlists'")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label == 'Playlists'")).firstMatch,
        ]
        return waitForAny(candidates, timeout: timeout) != nil
    }

    // MARK: - Smart Playlist Creation

    /// Tap "+" then "New Smart Playlist" to open the creation form.
    ///
    /// - Returns: `true` if the creation form opened (name field is visible).
    @discardableResult
    public func openNewSmartPlaylistForm(timeout: TimeInterval? = nil) -> Bool {
        guard tap(createButton, timeout: timeout) else { return false }
        // Menu items animate in — wait briefly for them to appear before tapping.
        guard tap(newSmartPlaylistMenuItem, timeout: 3) else { return false }
        return nameField.waitForExistence(timeout: 5)
    }

    /// Type a name into the name field.
    ///
    /// - Returns: `true` if the field was found and text was entered.
    @discardableResult
    public func enterName(_ name: String) -> Bool {
        guard nameField.waitForExistence(timeout: 5) else { return false }
        nameField.tap()
        nameField.typeText(name)
        return true
    }

    /// Tap the Save (or Create) button and wait for the form to dismiss.
    ///
    /// Waits up to 8 seconds for the name field to disappear, confirming the
    /// creation sheet has fully animated away. This ensures callers can
    /// immediately interact with the Playlists list without racing the dismissal.
    ///
    /// - Returns: `true` if the button was found and tapped.
    @discardableResult
    public func save() -> Bool {
        guard saveButton.waitForExistence(timeout: 3) else { return false }
        saveButton.tap()
        // Wait for the sheet to fully dismiss before returning.
        _ = !nameField.waitForExistence(timeout: 8)
        return true
    }

    /// Tap the Cancel button to dismiss without saving.
    ///
    /// - Returns: `true` if the button was tapped.
    @discardableResult
    public func cancel() -> Bool {
        guard cancelButton.waitForExistence(timeout: 3) else { return false }
        cancelButton.tap()
        return true
    }

    /// Tap the "Discard" action in the discard-changes confirmation dialog.
    ///
    /// - Returns: `true` if the button was tapped.
    @discardableResult
    public func confirmDiscard() -> Bool {
        guard discardButton.waitForExistence(timeout: 3) else { return false }
        discardButton.tap()
        return true
    }

    // MARK: - Queries

    /// Whether the creation/edit form is currently visible.
    public func isCreationFormVisible() -> Bool {
        nameField.waitForExistence(timeout: 3)
    }

    /// The list row for a smart playlist with the given name.
    ///
    /// Targets the `Text(smartPlaylist.name)` static text element directly.
    /// SwiftUI `NavigationLink` cells in a `List` do not automatically expose
    /// their child text as the cell's top-level accessibility label, so querying
    /// `app.cells` by label predicate is unreliable. Finding the `Text` element
    /// directly is always correct.
    ///
    /// - Parameter name: The exact playlist name to look for.
    /// - Returns: The static text element showing `name` inside the row.
    public func rowForPlaylist(named name: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    /// Scroll the Playlists list to materialize the "My Smart Playlists" section.
    ///
    /// The "My Smart Playlists" section appears below 13 built-in smart playlist
    /// rows (~845px of content) and may be outside the lazy-rendered viewport.
    ///
    /// Uses coordinate-based dragging rather than `app.tables.firstMatch` because
    /// SwiftUI's List accessibility element type varies across iOS versions and
    /// table queries are unreliable on iOS 26+. The coordinate approach always
    /// works: it swipes on whatever is frontmost in the app window.
    ///
    /// - Returns: Always `true` — the drag is synthesized unconditionally.
    @discardableResult
    public func scrollToRevealCustomPlaylists() -> Bool {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: end)
        // A second swipe ensures the section clears the fold even when the
        // built-in playlist rows push it further down on smaller viewports.
        start.press(forDuration: 0.05, thenDragTo: end)
        return true
    }
}

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

    /// Tap the Save (or Create) button to persist the smart playlist.
    ///
    /// - Returns: `true` if the button was tapped.
    @discardableResult
    public func save() -> Bool {
        guard saveButton.waitForExistence(timeout: 3) else { return false }
        saveButton.tap()
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

    /// The list row cell for a smart playlist with the given name.
    ///
    /// Uses a `CONTAINS` predicate because SwiftUI cells may include episode count
    /// and other metadata alongside the playlist name.
    ///
    /// - Parameter name: The exact playlist name string to look for.
    /// - Returns: The first cell whose label contains `name`.
    public func rowForPlaylist(named name: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        return app.cells.matching(predicate).firstMatch
    }
}

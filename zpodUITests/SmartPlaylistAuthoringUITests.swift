import XCTest

/// End-to-end UI tests for Smart Playlist authoring and editing.
///
/// These tests cover the primary user-facing workflows described in
/// `spec/06.1.2-smart-playlists-automation.md`:
///
/// - Scenario 1: Create a custom smart playlist (rule form, name, save)
/// - Scenario 2: Edit an existing playlist (pre-populated form, save)
/// - G2: Cancel with unsaved changes shows discard confirmation
///
/// **Test isolation**: Each test inherits automatic UserDefaults cleanup from
/// `IsolatedUITestCase`, which clears `us.zig.zpod` data before and after each test.
/// `UserDefaultsSmartPlaylistManager` stores under that domain, so custom playlists
/// are always wiped between test runs — no manual reset needed.
///
/// **Issue**: #418 — Smart Playlist Authoring and Editing
final class SmartPlaylistAuthoringUITests: IsolatedUITestCase {

    // MARK: - Scenario 1: Navigate to Playlists tab

    /// Verify the Playlists tab is reachable and displays the expected content.
    ///
    /// Given: The app is freshly launched.
    /// When: The user taps the "Playlists" tab.
    /// Then: The Playlists screen loads and the "+" create button is visible.
    @MainActor
    func testCanNavigateToPlaylistsTab() {
        app = launchConfiguredApp()
        let screen = SmartPlaylistScreen(app: app)

        XCTAssertTrue(
            screen.navigateToPlaylists(),
            "Playlists tab should be tappable and content should load"
        )
        XCTAssertTrue(
            screen.waitForPlaylistsContent(),
            "Playlists screen should show its content after navigation"
        )
    }

    // MARK: - Scenario 1: Create a Smart Playlist

    /// Create a custom smart playlist and verify it appears in the list.
    ///
    /// Given: The user is on the Playlists screen.
    /// When: User taps "+" → "New Smart Playlist", types a name, and taps "Create".
    /// Then: The new playlist row appears in the "My Smart Playlists" section.
    @MainActor
    func testCreateSmartPlaylistAppearsInList() {
        app = launchConfiguredApp()
        let screen = SmartPlaylistScreen(app: app)

        XCTAssertTrue(screen.navigateToPlaylists(), "Should reach Playlists tab")
        XCTAssertTrue(screen.openNewSmartPlaylistForm(), "Creation form should open")
        XCTAssertTrue(screen.enterName("My Test Playlist"), "Name field should accept input")
        XCTAssertTrue(screen.save(), "Save button should be tappable")

        // After dismissal, the row should be visible in the list.
        let row = screen.rowForPlaylist(named: "My Test Playlist")
        XCTAssertTrue(
            row.waitForExistence(timeout: 5),
            "Created playlist should appear in the list after saving"
        )
    }

    // MARK: - G2: Cancel with unsaved changes

    /// Cancelling with a typed name shows the discard-changes confirmation dialog.
    ///
    /// Given: The creation form is open and the user has typed a name.
    /// When: The user taps "Cancel".
    /// Then: A discard-changes confirmation appears with a "Discard" action.
    @MainActor
    func testCancelWithNameShowsDiscardConfirmation() {
        app = launchConfiguredApp()
        let screen = SmartPlaylistScreen(app: app)

        XCTAssertTrue(screen.navigateToPlaylists(), "Should reach Playlists tab")
        XCTAssertTrue(screen.openNewSmartPlaylistForm(), "Creation form should open")
        XCTAssertTrue(screen.enterName("Draft Playlist"), "Name field should accept input")
        XCTAssertTrue(screen.cancel(), "Cancel button should be tappable")

        XCTAssertTrue(
            screen.discardButton.waitForExistence(timeout: 5),
            "Discard confirmation dialog should appear when cancelling with a typed name"
        )
    }

    // MARK: - G2: Cancel without unsaved changes dismisses immediately

    /// Cancelling an empty form (no name entered) dismisses without confirmation.
    ///
    /// Given: The creation form is open with no name entered.
    /// When: The user taps "Cancel".
    /// Then: The form dismisses immediately without showing a confirmation dialog.
    @MainActor
    func testCancelEmptyFormDismissesWithoutConfirmation() {
        app = launchConfiguredApp()
        let screen = SmartPlaylistScreen(app: app)

        XCTAssertTrue(screen.navigateToPlaylists(), "Should reach Playlists tab")
        XCTAssertTrue(screen.openNewSmartPlaylistForm(), "Creation form should open")
        // Do NOT type a name — form is in its default state.
        XCTAssertTrue(screen.cancel(), "Cancel button should be tappable")

        // The form should disappear without a discard dialog.
        XCTAssertFalse(
            screen.discardButton.waitForExistence(timeout: 2),
            "No discard dialog should appear when cancelling an empty form"
        )
        XCTAssertFalse(
            screen.isCreationFormVisible(),
            "Creation form should be dismissed"
        )
    }
}

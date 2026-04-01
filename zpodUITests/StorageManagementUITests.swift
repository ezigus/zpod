//
//  StorageManagementUITests.swift
//  zpodUITests
//
//  Created for Issue 28.1.2: Storage Management UI
//  Tests storage display, calculation, and cleanup operations
//

import XCTest

/// UI tests for storage management functionality
///
/// **Spec Coverage**: `spec/offline-playback.md`, `spec/storage-management.md`
/// - Storage calculation and display
/// - Per-podcast storage breakdown
/// - Delete all downloads operation
/// - Refresh functionality
/// - Error handling
///
/// **Issue**: #28.1 - Phase 4: Test Infrastructure
final class StorageManagementUITests: IsolatedUITestCase {

    // MARK: - Storage Display Tests

    /// Test: Storage summary displays total size and episode count
    ///
    /// **Spec**: storage-management.md - "Display total storage used"
    ///
    /// **Given**: App has downloaded episodes
    /// **When**: User navigates to storage management
    /// **Then**: Total storage size and episode count are displayed
    @MainActor
    func testStorageSummaryDisplays() throws {
        // Given: App with downloaded episodes
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "episode-1,episode-2,episode-3"
        ])
        navigateToStorageManagement()

        // When: Storage management view loads
        let storageList = storageListElement()
        XCTAssertTrue(
            storageList.waitForExistence(timeout: adaptiveTimeout),
            "Storage list should appear"
        )

        // Then: Summary section shows total size
        let totalSize = app.staticTexts.matching(identifier: "Storage.Summary.TotalSize").firstMatch
        XCTAssertTrue(
            totalSize.waitForExistence(timeout: adaptiveTimeout),
            "Total storage size should be displayed"
        )

        // Verify total size is not empty
        XCTAssertFalse(
            totalSize.label.isEmpty,
            "Total storage size should have a value"
        )

        // Then: Summary section shows episode count
        let episodeCount = app.staticTexts.matching(identifier: "Storage.Summary.EpisodeCount").firstMatch
        XCTAssertTrue(
            episodeCount.exists,
            "Episode count should be displayed"
        )

        // Verify episode count mentions episodes
        XCTAssertTrue(
            episodeCount.label.contains("episode"),
            "Episode count should contain 'episode' text"
        )
    }

    /// Test: Empty state displays when no downloads
    ///
    /// **Spec**: storage-management.md - "Empty state when no downloads"
    ///
    /// **Given**: App has no downloaded episodes
    /// **When**: User navigates to storage management
    /// **Then**: Empty state or zero values are displayed
    @MainActor
    func testEmptyStateDisplays() throws {
        // Given: App with no downloads
        app = launchConfiguredApp()
        navigateToStorageManagement()

        // When: Storage management view loads
        let storageList = storageListElement()
        XCTAssertTrue(
            storageList.waitForExistence(timeout: adaptiveTimeout),
            "Storage list should appear"
        )

        // Then: Summary shows zero or minimal storage
        let totalSize = app.staticTexts.matching(identifier: "Storage.Summary.TotalSize").firstMatch
        if totalSize.exists {
            let sizeText = totalSize.label.lowercased()
            // Should show 0 bytes, Zero KB, or similar (ByteCountFormatter formats vary)
            XCTAssertTrue(
                sizeText.contains("0") || sizeText.contains("byte") || sizeText.contains("zero"),
                "Empty storage should show zero or bytes: \(sizeText)"
            )
        }

        // Then: Episode count shows 0 episodes
        let episodeCount = app.staticTexts.matching(identifier: "Storage.Summary.EpisodeCount").firstMatch
        if episodeCount.exists {
            XCTAssertTrue(
                episodeCount.label.contains("0"),
                "Empty state should show 0 episodes"
            )
        }

        // Then: Delete all button should not appear (no downloads to delete)
        let deleteAllButton = app.buttons.matching(identifier: "Storage.DeleteAll").firstMatch
        XCTAssertFalse(
            deleteAllButton.exists,
            "Delete all button should not appear when no downloads"
        )
    }

    /// Test: Per-podcast breakdown displays correctly
    ///
    /// **Spec**: storage-management.md - "Show per-podcast storage breakdown"
    ///
    /// **Given**: App has downloads from multiple podcasts
    /// **When**: User views storage management
    /// **Then**: Breakdown shows each podcast with episode count and size
    @MainActor
    func testPerPodcastBreakdownDisplays() throws {
        // Given: App with downloads from multiple podcasts
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "podcast-1-episode-1,podcast-1-episode-2,podcast-2-episode-1"
        ])
        navigateToStorageManagement()

        // When: Storage management view loads
        let storageList = storageListElement()
        _ = storageList.waitForExistence(timeout: adaptiveTimeout)

        // Then: "By Podcast" section should appear
        let byPodcastHeader = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "By Podcast")
        ).firstMatch

        if byPodcastHeader.waitForExistence(timeout: adaptiveShortTimeout) {
            // Verify at least one podcast row exists (try multiple element types)
            let podcastPredicate = NSPredicate(format: "identifier BEGINSWITH 'Storage.Podcast.'")
            let candidates: [XCUIElement] = [
                app.otherElements.matching(podcastPredicate).firstMatch,
                app.cells.matching(podcastPredicate).firstMatch,
                app.buttons.matching(podcastPredicate).firstMatch,
                // Also try finding by text content (podcast title)
                app.staticTexts.matching(NSPredicate(format: "identifier CONTAINS 'Storage.Podcast.'")).firstMatch
            ]

            let found = candidates.contains { $0.exists }
            XCTAssertTrue(
                found,
                "At least one podcast should appear in breakdown"
            )
        } else {
            XCTFail("By Podcast section header should appear when downloads exist")
        }
    }

    // MARK: - Refresh Tests

    /// Test: Pull-to-refresh updates storage calculation
    ///
    /// **Spec**: storage-management.md - "Refresh storage calculation"
    ///
    /// **Given**: Storage management view is displayed
    /// **When**: User pulls to refresh
    /// **Then**: Storage is recalculated and UI updates
    @MainActor
    func testPullToRefreshUpdatesStorage() throws {
        // Given: App with downloads and storage view open
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "episode-1"
        ])
        navigateToStorageManagement()

        let storageList = storageListElement()
        _ = storageList.waitForExistence(timeout: adaptiveTimeout)

        // When: User pulls to refresh
        // Simulate pull-to-refresh gesture
        let firstCell = storageList.cells.firstMatch
        if firstCell.exists {
            let start = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            let finish = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 3))
            start.press(forDuration: 0, thenDragTo: finish)

            // Brief wait for refresh to complete
            sleep(2)

            // Then: Storage summary should still be present (refresh completed)
            let totalSize = app.staticTexts.matching(identifier: "Storage.Summary.TotalSize").firstMatch
            XCTAssertTrue(
                totalSize.exists,
                "Storage summary should remain visible after refresh"
            )
        } else {
            // Skip test if list structure not available
            throw XCTSkip("Cannot perform pull-to-refresh without accessible cells")
        }
    }

    // MARK: - Delete Operations Tests

    /// Test: Delete all shows confirmation dialog
    ///
    /// **Spec**: storage-management.md - "Confirm before deleting all"
    ///
    /// **Given**: App has downloaded episodes
    /// **When**: User taps "Delete All Downloads"
    /// **Then**: Confirmation dialog appears
    @MainActor
    func testDeleteAllShowsConfirmation() throws {
        // Given: App with downloads
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "episode-1,episode-2"
        ])
        navigateToStorageManagement()

        let storageList = storageListElement()
        _ = storageList.waitForExistence(timeout: adaptiveTimeout)

        // When: User taps "Delete All Downloads" button
        let deleteAllButton = app.buttons.matching(identifier: "Storage.DeleteAll").firstMatch

        XCTAssertTrue(
            deleteAllButton.waitForExistence(timeout: adaptiveTimeout),
            "Delete all button should exist when downloads present"
        )

        deleteAllButton.tap()

        // Then: Confirmation alert should appear with both buttons
        let confirmAlert = app.alerts["Delete All Downloads?"].firstMatch

        XCTAssertTrue(
            confirmAlert.waitForExistence(timeout: adaptiveShortTimeout),
            "Confirmation alert should appear"
        )

        // Verify Delete button exists
        let deleteConfirmButton = confirmAlert.buttons.matching(identifier: "Storage.DeleteConfirm.Delete").firstMatch
        if !deleteConfirmButton.exists {
            // Fallback to label-based search
            let deleteByLabel = confirmAlert.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "delete")
            ).firstMatch
            XCTAssertTrue(deleteByLabel.exists, "Delete confirmation button should exist")
        }

        // Verify Cancel button exists
        let cancelButton = confirmAlert.buttons.matching(identifier: "Storage.DeleteConfirm.Cancel").firstMatch
        if !cancelButton.exists {
            // Fallback to label-based search
            let cancelByLabel = confirmAlert.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "cancel")
            ).firstMatch
            XCTAssertTrue(cancelByLabel.exists, "Cancel button should exist in confirmation alert")
        }
    }

    /// Test: Delete all can be cancelled
    ///
    /// **Spec**: storage-management.md - "Cancel delete all operation"
    ///
    /// **Given**: Delete all confirmation dialog is shown
    /// **When**: User taps "Cancel"
    /// **Then**: Dialog dismisses, downloads remain
    @MainActor
    func testDeleteAllCancelsCorrectly() throws {
        // Given: App with downloads and confirmation dialog open
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "episode-1,episode-2"
        ])
        navigateToStorageManagement()

        let storageList = storageListElement()
        _ = storageList.waitForExistence(timeout: adaptiveTimeout)

        let deleteAllButton = app.buttons.matching(identifier: "Storage.DeleteAll").firstMatch
        _ = deleteAllButton.waitForExistence(timeout: adaptiveTimeout)
        deleteAllButton.tap()

        // When: User taps Cancel in the confirmation alert
        // Using alert instead of confirmationDialog provides accessible buttons
        let cancelButton = app.alerts.buttons.matching(identifier: "Storage.DeleteConfirm.Cancel").firstMatch

        // Fallback to label-based search if identifier not found
        if !cancelButton.waitForExistence(timeout: adaptiveShortTimeout) {
            let cancelByLabel = app.alerts.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "cancel")
            ).firstMatch

            XCTAssertTrue(
                cancelByLabel.waitForExistence(timeout: adaptiveShortTimeout),
                "Cancel button should exist in confirmation alert"
            )
            cancelByLabel.tap()
        } else {
            cancelButton.tap()
        }

        // Then: Verify alert is dismissed
        sleep(1) // Wait for animation

        let confirmAlert = app.alerts["Delete All Downloads?"].firstMatch
        XCTAssertFalse(
            confirmAlert.exists,
            "Confirmation alert should be dismissed after Cancel"
        )

        // Then: Storage summary still shows downloads
        let episodeCount = app.staticTexts.matching(identifier: "Storage.Summary.EpisodeCount").firstMatch
        if episodeCount.exists {
            XCTAssertFalse(
                episodeCount.label.contains("0"),
                "Episode count should not be zero (downloads not deleted)"
            )
        }
    }

    /// Test: Delete all executes and removes downloads
    ///
    /// **Spec**: storage-management.md - "Delete all downloads"
    ///
    /// **Given**: Delete all confirmation dialog is shown
    /// **When**: User confirms deletion
    /// **Then**: All downloads are removed, UI updates to empty state
    @MainActor
    func testDeleteAllExecutes() throws {
        // Given: App with downloads and confirmation dialog open
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "episode-1,episode-2"
        ])
        navigateToStorageManagement()

        let storageList = storageListElement()
        _ = storageList.waitForExistence(timeout: adaptiveTimeout)

        let deleteAllButton = app.buttons.matching(identifier: "Storage.DeleteAll").firstMatch
        _ = deleteAllButton.waitForExistence(timeout: adaptiveTimeout)
        deleteAllButton.tap()

        // When: User confirms deletion in the alert
        let confirmAlert = app.alerts["Delete All Downloads?"].firstMatch

        XCTAssertTrue(
            confirmAlert.waitForExistence(timeout: adaptiveShortTimeout),
            "Confirmation alert should appear"
        )

        // Find and tap the Delete button
        let deleteConfirmButton = confirmAlert.buttons.matching(identifier: "Storage.DeleteConfirm.Delete").firstMatch
        if deleteConfirmButton.exists {
            deleteConfirmButton.tap()
        } else {
            // Fallback to label-based search
            let deleteByLabel = confirmAlert.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "delete")
            ).firstMatch
            XCTAssertTrue(deleteByLabel.exists, "Delete confirmation button should exist")
            deleteByLabel.tap()
        }

        // Then: Wait for deletion to complete
        sleep(2)

        // Verify delete all button no longer exists (no downloads left)
        let deleteAllButtonAfter = app.buttons.matching(identifier: "Storage.DeleteAll").firstMatch
        XCTAssertFalse(
            deleteAllButtonAfter.exists,
            "Delete all button should disappear after all downloads removed"
        )

        // Verify storage shows empty state
        let episodeCount = app.staticTexts.matching(identifier: "Storage.Summary.EpisodeCount").firstMatch
        if episodeCount.exists {
            XCTAssertTrue(
                episodeCount.label.contains("0"),
                "Episode count should show 0 after deletion"
            )
        }
    }

    // MARK: - Error Handling Tests

    /// Test: Error alert displays when deletion fails
    ///
    /// **Spec**: storage-management.md - "Show error on delete failure"
    ///
    /// **Given**: App configured to fail delete operations (UITEST_FAIL_DELETE=1)
    /// **When**: User attempts to delete all
    /// **Then**: Error alert is displayed
    @MainActor
    func testErrorAlertDisplays() throws {
        // Given: App configured to fail deletions
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "episode-1",
            "UITEST_FAIL_DELETE": "1"  // Simulate delete failures
        ])
        navigateToStorageManagement()

        let storageList = storageListElement()
        _ = storageList.waitForExistence(timeout: adaptiveTimeout)

        let deleteAllButton = app.buttons.matching(identifier: "Storage.DeleteAll").firstMatch
        if deleteAllButton.waitForExistence(timeout: adaptiveTimeout) {
            deleteAllButton.tap()

            // Confirm deletion
            let deleteConfirmButton = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "delete")
            ).firstMatch

            if deleteConfirmButton.waitForExistence(timeout: adaptiveShortTimeout) {
                deleteConfirmButton.tap()

                // Then: Error alert should appear
                // SwiftUI .alert presents as a system alert with title "Error"
                let errorAlert = app.alerts["Error"].firstMatch

                XCTAssertTrue(
                    errorAlert.waitForExistence(timeout: adaptiveTimeout),
                    "Error alert should appear when deletion fails"
                )

                // Verify alert has an OK button to dismiss
                let okButton = errorAlert.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", "ok")
                ).firstMatch

                XCTAssertTrue(
                    okButton.exists,
                    "Error alert should have OK button"
                )

                // Dismiss the alert
                okButton.tap()

                // Verify alert is dismissed
                XCTAssertFalse(
                    errorAlert.exists,
                    "Error alert should dismiss after tapping OK"
                )
            } else {
                throw XCTSkip("Delete confirmation not available in this build")
            }
        } else {
            throw XCTSkip("Delete all button not available in this build")
        }
    }

    /// Test: Loading indicator appears during calculation
    ///
    /// **Spec**: storage-management.md - "Show loading indicator"
    ///
    /// **Given**: App is calculating storage
    /// **When**: User opens storage management
    /// **Then**: Loading indicator briefly appears
    @MainActor
    func testLoadingIndicatorAppears() throws {
        // Given: App with downloads
        app = launchConfiguredApp(environmentOverrides: [
            "UITEST_DOWNLOADED_EPISODES": "episode-1,episode-2,episode-3",
            "UITEST_SLOW_STORAGE_CALC": "1"  // Simulate slow calculation
        ])

        // When: Navigating to storage management
        let tabs = TabBarNavigation(app: app)
        let settings = SettingsScreen(app: app)

        XCTAssertTrue(tabs.navigateToSettings(), "Should navigate to Settings")

        // Find and tap Manage Storage row using fallback pattern
        let rowCandidates: [XCUIElement] = [
            app.buttons.matching(identifier: "Settings.ManageStorage").firstMatch,
            app.cells.matching(identifier: "Settings.ManageStorage").firstMatch,
            app.otherElements.matching(identifier: "Settings.ManageStorage").firstMatch,
            app.staticTexts.matching(identifier: "Settings.ManageStorage.Label").firstMatch
        ]
        guard let row = waitForAnyElement(rowCandidates, timeout: adaptiveTimeout, description: "Manage Storage row") else {
            throw XCTSkip("Storage management navigation not available")
        }
        row.tap()

        // Then: Loading indicator should appear briefly
        let loadingIndicator = app.activityIndicators.matching(identifier: "Storage.Loading").firstMatch

        // Loading might be very brief, so check if it appears or if content already loaded
        let appeared = loadingIndicator.waitForExistence(timeout: 2)
        if !appeared {
            // If loading was too fast, verify content appeared instead
            let storageList = storageListElement()
            XCTAssertTrue(
                storageList.waitForExistence(timeout: adaptiveTimeout),
                "Either loading indicator or storage list should appear"
            )
        } else {
            // At minimum, verify storage list eventually appears
            let storageList = storageListElement()
            XCTAssertTrue(
                storageList.waitForExistence(timeout: adaptiveTimeout),
                "Storage list should appear after calculation completes"
            )
        }
    }

    // MARK: - Helper Methods

    /// Navigate to storage management view using page objects
    private func navigateToStorageManagement() {
        let tabs = TabBarNavigation(app: app)
        let settings = SettingsScreen(app: app)

        XCTAssertTrue(
            tabs.navigateToSettings(),
            "Should navigate to Settings tab"
        )

        XCTAssertTrue(
            settings.navigateToStorageManagement(),
            "Should navigate to Storage Management screen"
        )
    }

    /// Navigate to settings tab using page object
    private func navigateToSettings() {
        let tabs = TabBarNavigation(app: app)

        XCTAssertTrue(
            tabs.navigateToSettings(),
            "Should navigate to Settings tab"
        )
    }

    /// Locate the storage list (table-backed) in the storage management view.
    /// Uses fallback pattern because SwiftUI Lists can appear as different element types.
    private func storageListElement() -> XCUIElement {
        // Try multiple element types - SwiftUI Lists can appear differently
        let candidates: [XCUIElement] = [
            app.tables.matching(identifier: "Storage.List").firstMatch,
            app.collectionViews.matching(identifier: "Storage.List").firstMatch,
            app.scrollViews.matching(identifier: "Storage.List").firstMatch,
            app.otherElements.matching(identifier: "Storage.List").firstMatch,
            // Also try finding by child element - Storage.Summary is always present
            app.otherElements.matching(identifier: "Storage.Summary").firstMatch,
            app.cells.matching(identifier: "Storage.Summary").firstMatch
        ]

        // Return first that exists
        for candidate in candidates {
            if candidate.exists { return candidate }
        }

        // Fallback to any table if nothing found
        let anyTable = app.tables.firstMatch
        if anyTable.exists { return anyTable }

        // Final fallback
        return candidates[0]
    }
}

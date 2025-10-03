import XCTest
@testable import LibraryFeature
@testable import CoreModels

@MainActor
final class SwipeActionConfigurationViewModelTests: XCTestCase {
    private final class SettingsManagerStub: UISettingsManaging {
        var globalUISettings: UISettings
        private(set) var savedSettings: [UISettings] = []
        init(initial: UISettings) {
            self.globalUISettings = initial
        }
        func updateGlobalUISettings(_ settings: UISettings) async {
            savedSettings.append(settings)
            globalUISettings = settings
        }
    }

    func testInitialStateReflectsManagerSettings() {
        let initialSettings = UISettings(
            swipeActions: SwipeActionSettings(
                leadingActions: [.play, .download],
                trailingActions: [.delete],
                allowFullSwipeLeading: true,
                allowFullSwipeTrailing: false,
                hapticFeedbackEnabled: true
            ),
            hapticStyle: .heavy
        )
        let manager = SettingsManagerStub(initial: initialSettings)
        let viewModel = SwipeActionConfigurationViewModel(settingsManager: manager)

        XCTAssertEqual(viewModel.leadingActions, [.play, .download])
        XCTAssertEqual(viewModel.trailingActions, [.delete])
        XCTAssertTrue(viewModel.allowFullSwipeLeading)
        XCTAssertFalse(viewModel.allowFullSwipeTrailing)
        XCTAssertTrue(viewModel.hapticsEnabled)
        XCTAssertEqual(viewModel.hapticStyle, .heavy)
        XCTAssertFalse(viewModel.hasUnsavedChanges)
    }

    func testAddingActionDoesNotExceedMaximum() {
        let manager = SettingsManagerStub(initial: .default)
        let viewModel = SwipeActionConfigurationViewModel(settingsManager: manager)

        viewModel.addAction(.download, to: .leading)
        viewModel.addAction(.favorite, to: .leading)
        viewModel.addAction(.archive, to: .leading)
        viewModel.addAction(.share, to: .leading) // should be ignored due to cap

        XCTAssertEqual(viewModel.leadingActions.count, 3)
        XCTAssertFalse(viewModel.leadingActions.contains(.share))
    }

    func testApplyPresetReplacesDraft() {
        let manager = SettingsManagerStub(initial: .default)
        let viewModel = SwipeActionConfigurationViewModel(settingsManager: manager)

        viewModel.applyPreset(.organizationFocused)

        XCTAssertEqual(viewModel.leadingActions, SwipeActionSettings.organizationFocused.leadingActions)
        XCTAssertEqual(viewModel.trailingActions, SwipeActionSettings.organizationFocused.trailingActions)
        XCTAssertTrue(viewModel.allowFullSwipeLeading)
        XCTAssertFalse(viewModel.allowFullSwipeTrailing)
        XCTAssertTrue(viewModel.hasUnsavedChanges)
    }

    func testSavePersistsChanges() async {
        let manager = SettingsManagerStub(initial: .default)
        let viewModel = SwipeActionConfigurationViewModel(settingsManager: manager)

        viewModel.setHapticsEnabled(false)
        viewModel.setHapticStyle(.rigid)
        viewModel.toggleFullSwipe(.trailing)

        await viewModel.saveChanges()

        XCTAssertEqual(manager.savedSettings.count, 1)
        let saved = manager.savedSettings.first
        XCTAssertEqual(saved?.hapticStyle, .rigid)
        XCTAssertFalse(saved?.swipeActions.hapticFeedbackEnabled ?? true)
        XCTAssertTrue(saved?.swipeActions.allowFullSwipeTrailing ?? false)
        XCTAssertFalse(viewModel.hasUnsavedChanges)
    }
}

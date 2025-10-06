import XCTest
import CoreModels
@testable import SettingsDomain

@MainActor
final class SwipeConfigurationControllerTests: XCTestCase {
  func testLoadBaselinePopulatesDraft() async {
    // Given
    let initial = SwipeConfiguration(
      swipeActions: SwipeActionSettings(
        leadingActions: [.play],
        trailingActions: [.download],
        allowFullSwipeLeading: true,
        allowFullSwipeTrailing: false,
        hapticFeedbackEnabled: true
      ),
      hapticStyle: .soft
    )
    let service = InMemorySwipeConfigurationService(initial: initial)
    let controller = SwipeConfigurationController(service: service)

    // When
    await controller.loadBaseline()

    // Then
    XCTAssertEqual(controller.draft, initial)
    XCTAssertFalse(controller.hasUnsavedChanges)
  }

  func testMutatingDraftMarksUnsavedAndCommitPersists() async throws {
    // Given
    let initial = SwipeConfiguration(
      swipeActions: .default,
      hapticStyle: .medium
    )
    let service = InMemorySwipeConfigurationService(initial: initial)
    let controller = SwipeConfigurationController(service: service)
    await controller.loadBaseline()

    // When
    controller.updateDraft { draft in
      draft.swipeActions = SwipeActionSettings(
        leadingActions: [.favorite, .addToPlaylist],
        trailingActions: [.archive],
        allowFullSwipeLeading: false,
        allowFullSwipeTrailing: true,
        hapticFeedbackEnabled: false
      )
      draft.hapticStyle = .heavy
    }

    // Then
    XCTAssertTrue(controller.hasUnsavedChanges)

    try await controller.commitChanges()

    XCTAssertFalse(controller.hasUnsavedChanges)
    let persisted = await service.load()
    XCTAssertEqual(persisted.swipeActions.leadingActions, [.favorite, .addToPlaylist])

  func testApplyPresetUpdatesActionsAndFlagsUnsavedChanges() async {
    let service = InMemorySwipeConfigurationService(initial: .default)
    let controller = SwipeConfigurationController(service: service)
    await controller.loadBaseline()

    controller.applyPreset(.playbackFocused)

    XCTAssertEqual(controller.leadingActions, [.play, .addToPlaylist])
    XCTAssertEqual(controller.trailingActions, [.download, .favorite])
    XCTAssertTrue(controller.hasUnsavedChanges)
  }

  func testAddActionStopsAtThreeEntriesPerEdge() async {
    let service = InMemorySwipeConfigurationService(initial: .default)
    let controller = SwipeConfigurationController(service: service)
    await controller.loadBaseline()

    controller.removeAction(.markPlayed, edge: .leading)
    controller.addAction(.play, edge: .leading)
    controller.addAction(.addToPlaylist, edge: .leading)
    controller.addAction(.favorite, edge: .leading)

    XCTAssertEqual(controller.leadingActions, [.play, .addToPlaylist, .favorite])
    XCTAssertFalse(controller.canAddMoreActions(to: .leading))

    controller.addAction(.download, edge: .leading)
    XCTAssertEqual(controller.leadingActions, [.play, .addToPlaylist, .favorite])
  }
    XCTAssertEqual(persisted.hapticStyle, .heavy)
  }
}

actor InMemorySwipeConfigurationService: SwipeConfigurationServicing {
  var storedConfiguration: SwipeConfiguration
  private var continuation: AsyncStream<SwipeConfiguration>.Continuation?

  init(initial: SwipeConfiguration) {
    self.storedConfiguration = initial
  }

  func load() async -> SwipeConfiguration {
    storedConfiguration
  }

  func save(_ configuration: SwipeConfiguration) async throws {
    storedConfiguration = configuration
    continuation?.yield(configuration)
  }

  nonisolated func updatesStream() -> AsyncStream<SwipeConfiguration> {
    AsyncStream { continuation in
      Task { await self.storeContinuation(continuation) }
    }
  }

  private func storeContinuation(_ continuation: AsyncStream<SwipeConfiguration>.Continuation) {
    self.continuation = continuation
  }
}

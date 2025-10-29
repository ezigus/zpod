//
//  SwipeActionHandlerTests.swift
//  LibraryFeatureTests
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Tests for swipe action handling
//

import XCTest
@testable import LibraryFeature
import CoreModels
import SettingsDomain
import SharedUtilities

final class SwipeActionHandlerTests: XCTestCase {
  
  private var handler: SwipeActionHandler!
  private var mockHapticsService: MockHapticFeedbackService!
  private var testEpisode: Episode!
  private var actionCallbacks: [String: Int] = [:]
  
  @MainActor
  override func setUpWithError() throws {
    continueAfterFailure = false
    
    mockHapticsService = MockHapticFeedbackService()
    handler = SwipeActionHandler(hapticFeedbackService: mockHapticsService)
    
    testEpisode = Episode(
      id: "test-episode",
      title: "Test Episode",
      podcastID: "test-podcast",
      pubDate: Date(),
      duration: 1800,
      description: "Test"
    )
    
    actionCallbacks = [:]
  }
  
  @MainActor
  override func tearDownWithError() throws {
    handler = nil
    mockHapticsService = nil
    testEpisode = nil
    actionCallbacks = [:]
  }
  
  // MARK: - Swipe Action Tests
  
  @MainActor
  func testPerformPlayAction() async {
    // Given: A play action
    var playedEpisode: Episode?
    
    // When: Performing the action
    handler.performSwipeAction(
      .play,
      for: testEpisode,
      quickPlayHandler: { episode in
        playedEpisode = episode
      },
      downloadHandler: { _ in },
      markPlayedHandler: { _ in },
      markUnplayedHandler: { _ in },
      playlistSelectionHandler: { _ in },
      favoriteToggleHandler: { _ in },
      archiveToggleHandler: { _ in },
      deleteHandler: { _ in },
      shareHandler: { _ in }
    )
    
    // Allow async task to complete
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // Then: Quick play handler should be called
    XCTAssertNotNil(playedEpisode)
    XCTAssertEqual(playedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformDownloadAction() {
    // Given: A download action
    var downloadedEpisode: Episode?
    
    // When: Performing the action
    handler.performSwipeAction(
      .download,
      for: testEpisode,
      quickPlayHandler: { _ in },
      downloadHandler: { episode in
        downloadedEpisode = episode
      },
      markPlayedHandler: { _ in },
      markUnplayedHandler: { _ in },
      playlistSelectionHandler: { _ in },
      favoriteToggleHandler: { _ in },
      archiveToggleHandler: { _ in },
      deleteHandler: { _ in },
      shareHandler: { _ in }
    )
    
    // Then: Download handler should be called
    XCTAssertNotNil(downloadedEpisode)
    XCTAssertEqual(downloadedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformMarkPlayedAction() {
    // Given: A mark played action
    var markedEpisode: Episode?
    
    // When: Performing the action
    handler.performSwipeAction(
      .markPlayed,
      for: testEpisode,
      quickPlayHandler: { _ in },
      downloadHandler: { _ in },
      markPlayedHandler: { episode in
        markedEpisode = episode
      },
      markUnplayedHandler: { _ in },
      playlistSelectionHandler: { _ in },
      favoriteToggleHandler: { _ in },
      archiveToggleHandler: { _ in },
      deleteHandler: { _ in },
      shareHandler: { _ in }
    )
    
    // Then: Mark played handler should be called
    XCTAssertNotNil(markedEpisode)
    XCTAssertEqual(markedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformMarkUnplayedAction() {
    // Given: A mark unplayed action
    var markedEpisode: Episode?
    
    // When: Performing the action
    handler.performSwipeAction(
      .markUnplayed,
      for: testEpisode,
      quickPlayHandler: { _ in },
      downloadHandler: { _ in },
      markPlayedHandler: { _ in },
      markUnplayedHandler: { episode in
        markedEpisode = episode
      },
      playlistSelectionHandler: { _ in },
      favoriteToggleHandler: { _ in },
      archiveToggleHandler: { _ in },
      deleteHandler: { _ in },
      shareHandler: { _ in }
    )
    
    // Then: Mark unplayed handler should be called
    XCTAssertNotNil(markedEpisode)
    XCTAssertEqual(markedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformAddToPlaylistAction() {
    // Given: An add to playlist action
    var selectedEpisode: Episode?
    
    // When: Performing the action
    handler.performSwipeAction(
      .addToPlaylist,
      for: testEpisode,
      quickPlayHandler: { _ in },
      downloadHandler: { _ in },
      markPlayedHandler: { _ in },
      markUnplayedHandler: { _ in },
      playlistSelectionHandler: { episode in
        selectedEpisode = episode
      },
      favoriteToggleHandler: { _ in },
      archiveToggleHandler: { _ in },
      deleteHandler: { _ in },
      shareHandler: { _ in }
    )
    
    // Then: Playlist selection handler should be called
    XCTAssertNotNil(selectedEpisode)
    XCTAssertEqual(selectedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformFavoriteAction() {
    // Given: A favorite action
    var favoritedEpisode: Episode?
    
    // When: Performing the action
    handler.performSwipeAction(
      .favorite,
      for: testEpisode,
      quickPlayHandler: { _ in },
      downloadHandler: { _ in },
      markPlayedHandler: { _ in },
      markUnplayedHandler: { _ in },
      playlistSelectionHandler: { _ in },
      favoriteToggleHandler: { episode in
        favoritedEpisode = episode
      },
      archiveToggleHandler: { _ in },
      deleteHandler: { _ in },
      shareHandler: { _ in }
    )
    
    // Then: Favorite toggle handler should be called
    XCTAssertNotNil(favoritedEpisode)
    XCTAssertEqual(favoritedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformArchiveAction() {
    // Given: An archive action
    var archivedEpisode: Episode?
    
    // When: Performing the action
    handler.performSwipeAction(
      .archive,
      for: testEpisode,
      quickPlayHandler: { _ in },
      downloadHandler: { _ in },
      markPlayedHandler: { _ in },
      markUnplayedHandler: { _ in },
      playlistSelectionHandler: { _ in },
      favoriteToggleHandler: { _ in },
      archiveToggleHandler: { episode in
        archivedEpisode = episode
      },
      deleteHandler: { _ in },
      shareHandler: { _ in }
    )
    
    // Then: Archive toggle handler should be called
    XCTAssertNotNil(archivedEpisode)
    XCTAssertEqual(archivedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformDeleteAction() async {
    // Given: A delete action
    var deletedEpisode: Episode?
    
    // When: Performing the action
    handler.performSwipeAction(
      .delete,
      for: testEpisode,
      quickPlayHandler: { _ in },
      downloadHandler: { _ in },
      markPlayedHandler: { _ in },
      markUnplayedHandler: { _ in },
      playlistSelectionHandler: { _ in },
      favoriteToggleHandler: { _ in },
      archiveToggleHandler: { _ in },
      deleteHandler: { episode in
        deletedEpisode = episode
      },
      shareHandler: { _ in }
    )
    
    // Allow async task to complete
    do {
      try await Task.sleep(nanoseconds: 100_000_000)
    } catch {
      XCTFail("Task.sleep failed: \(error)")
    }
    
    // Then: Delete handler should be called
    XCTAssertNotNil(deletedEpisode)
    XCTAssertEqual(deletedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformShareAction() {
    // Given: A share action
    var sharedEpisode: Episode?
    
    // When: Performing the action
    handler.performSwipeAction(
      .share,
      for: testEpisode,
      quickPlayHandler: { _ in },
      downloadHandler: { _ in },
      markPlayedHandler: { _ in },
      markUnplayedHandler: { _ in },
      playlistSelectionHandler: { _ in },
      favoriteToggleHandler: { _ in },
      archiveToggleHandler: { _ in },
      deleteHandler: { _ in },
      shareHandler: { episode in
        sharedEpisode = episode
      }
    )
    
    // Then: Share handler should be called
    XCTAssertNotNil(sharedEpisode)
    XCTAssertEqual(sharedEpisode?.id, testEpisode.id)
  }
  
  // MARK: - Haptic Feedback Tests
  
  @MainActor
  func testTriggerHapticWhenEnabled() {
    // Given: A configuration with haptics enabled
    var config = SwipeConfiguration.default
    config.swipeActions.hapticFeedbackEnabled = true
    config.hapticStyle = .medium
    
    // When: Triggering haptic feedback
    handler.triggerHapticIfNeeded(configuration: config)
    
    // Then: Haptic service should be called
    XCTAssertEqual(mockHapticsService.impactCallCount, 1)
    XCTAssertEqual(mockHapticsService.lastIntensity, .medium)
  }
  
  @MainActor
  func testNoHapticWhenDisabled() {
    // Given: A configuration with haptics disabled
    var config = SwipeConfiguration.default
    config.swipeActions.hapticFeedbackEnabled = false
    
    // When: Triggering haptic feedback
    handler.triggerHapticIfNeeded(configuration: config)
    
    // Then: Haptic service should not be called
    XCTAssertEqual(mockHapticsService.impactCallCount, 0)
  }
  
  @MainActor
  func testHapticIntensityStyles() {
    // Test different haptic styles
    let styles: [HapticStyle] = [.light, .medium, .heavy]
    
    for style in styles {
      mockHapticsService.reset()
      
      var config = SwipeConfiguration.default
      config.swipeActions.hapticFeedbackEnabled = true
      config.hapticStyle = style
      
      handler.triggerHapticIfNeeded(configuration: config)
      
      let expectedIntensity = HapticFeedbackIntensity(style: style)
      XCTAssertEqual(mockHapticsService.lastIntensity, expectedIntensity)
    }
  }
}

// MARK: - Mock Haptic Feedback Service

private class MockHapticFeedbackService: HapticFeedbackServicing {
  var impactCallCount = 0
  var lastIntensity: HapticFeedbackIntensity?
  
  func impact(_ intensity: HapticFeedbackIntensity) {
    impactCallCount += 1
    lastIntensity = intensity
  }
  
  func reset() {
    impactCallCount = 0
    lastIntensity = nil
  }
}

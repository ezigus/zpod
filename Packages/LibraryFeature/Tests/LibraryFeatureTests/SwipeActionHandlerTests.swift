#if os(iOS)
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
    let callbacks = SwipeActionCallbacks(quickPlay: { episode in
      playedEpisode = episode
    })

    handler.performSwipeAction(.play, for: testEpisode, callbacks: callbacks)
    
    // Allow async task to complete
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // Then: Quick play handler should be called
    XCTAssertNotNil(playedEpisode)
    XCTAssertEqual(playedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformDownloadAction() {
    // Given: A download action
    var downloadedEpisode: Episode?
    
    // When: Performing the action
    let callbacks = SwipeActionCallbacks(download: { episode in
      downloadedEpisode = episode
    })

    handler.performSwipeAction(.download, for: testEpisode, callbacks: callbacks)
    
    // Then: Download handler should be called
    XCTAssertNotNil(downloadedEpisode)
    XCTAssertEqual(downloadedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformMarkPlayedAction() {
    // Given: A mark played action
    var markedEpisode: Episode?
    
    // When: Performing the action
    let callbacks = SwipeActionCallbacks(markPlayed: { episode in
      markedEpisode = episode
    })

    handler.performSwipeAction(.markPlayed, for: testEpisode, callbacks: callbacks)
    
    // Then: Mark played handler should be called
    XCTAssertNotNil(markedEpisode)
    XCTAssertEqual(markedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformMarkUnplayedAction() {
    // Given: A mark unplayed action
    var markedEpisode: Episode?
    
    // When: Performing the action
    let callbacks = SwipeActionCallbacks(markUnplayed: { episode in
      markedEpisode = episode
    })

    handler.performSwipeAction(.markUnplayed, for: testEpisode, callbacks: callbacks)
    
    // Then: Mark unplayed handler should be called
    XCTAssertNotNil(markedEpisode)
    XCTAssertEqual(markedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformAddToPlaylistAction() {
    // Given: An add to playlist action
    var selectedEpisode: Episode?
    
    // When: Performing the action
    let callbacks = SwipeActionCallbacks(selectPlaylist: { episode in
      selectedEpisode = episode
    })

    handler.performSwipeAction(.addToPlaylist, for: testEpisode, callbacks: callbacks)
    
    // Then: Playlist selection handler should be called
    XCTAssertNotNil(selectedEpisode)
    XCTAssertEqual(selectedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformFavoriteAction() {
    // Given: A favorite action
    var favoritedEpisode: Episode?
    
    // When: Performing the action
    let callbacks = SwipeActionCallbacks(toggleFavorite: { episode in
      favoritedEpisode = episode
    })

    handler.performSwipeAction(.favorite, for: testEpisode, callbacks: callbacks)
    
    // Then: Favorite toggle handler should be called
    XCTAssertNotNil(favoritedEpisode)
    XCTAssertEqual(favoritedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformArchiveAction() {
    // Given: An archive action
    var archivedEpisode: Episode?
    
    // When: Performing the action
    let callbacks = SwipeActionCallbacks(toggleArchive: { episode in
      archivedEpisode = episode
    })

    handler.performSwipeAction(.archive, for: testEpisode, callbacks: callbacks)
    
    // Then: Archive toggle handler should be called
    XCTAssertNotNil(archivedEpisode)
    XCTAssertEqual(archivedEpisode?.id, testEpisode.id)
  }
  
  @MainActor
  func testPerformDeleteAction() async {
    // Given: A delete action
    var deletedEpisode: Episode?
    
    // When: Performing the action
    let callbacks = SwipeActionCallbacks(deleteEpisode: { episode in
      deletedEpisode = episode
    })

    handler.performSwipeAction(.delete, for: testEpisode, callbacks: callbacks)
    
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
    let callbacks = SwipeActionCallbacks(shareEpisode: { episode in
      sharedEpisode = episode
    })

    handler.performSwipeAction(.share, for: testEpisode, callbacks: callbacks)
    
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

#endif

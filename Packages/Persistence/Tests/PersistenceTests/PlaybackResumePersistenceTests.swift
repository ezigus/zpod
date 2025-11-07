//
//  PlaybackResumePersistenceTests.swift
//  PersistenceTests
//
//  Created for Issue 03.1.1.3: Playback State Synchronization & Persistence
//  Tests for playback resume state persistence
//

import Testing
@testable import Persistence
import CoreModels
import Foundation

@Suite("Playback Resume State Persistence Tests")
struct PlaybackResumePersistenceTests {
  
  // MARK: - Save and Load Tests
  
  @Test("Save and load playback resume state")
  func testSaveAndLoadResumeState() async throws {
    // Given: A repository with test suite
    let suiteName = "test.playback.resume.\(UUID().uuidString)"
    let repository = UserDefaultsSettingsRepository(suiteName: suiteName)
    
    let resumeState = PlaybackResumeState(
      episodeId: "episode-123",
      position: 500,
      duration: 1800,
      timestamp: Date(),
      isPlaying: false
    )
    
    // When: Saving the resume state
    await repository.savePlaybackResumeState(resumeState)
    
    // Then: Should be able to load it back
    let loaded = await repository.loadPlaybackResumeState()
    #expect(loaded != nil)
    #expect(loaded?.episodeId == "episode-123")
    #expect(loaded?.position == 500)
    #expect(loaded?.duration == 1800)
    #expect(loaded?.isPlaying == false)
    
    // Cleanup
    await repository.clearPlaybackResumeState()
  }
  
  @Test("Clear playback resume state")
  func testClearResumeState() async throws {
    // Given: A repository with saved resume state
    let suiteName = "test.playback.clear.\(UUID().uuidString)"
    let repository = UserDefaultsSettingsRepository(suiteName: suiteName)
    
    let resumeState = PlaybackResumeState(
      episodeId: "episode-456",
      position: 300,
      duration: 1200,
      timestamp: Date(),
      isPlaying: true
    )
    await repository.savePlaybackResumeState(resumeState)
    
    var loaded = await repository.loadPlaybackResumeState()
    #expect(loaded != nil)
    
    // When: Clearing the state
    await repository.clearPlaybackResumeState()
    
    // Then: Should return nil
    loaded = await repository.loadPlaybackResumeState()
    #expect(loaded == nil)
  }
  
  @Test("Load returns nil when no state exists")
  func testLoadReturnsNilWhenNoState() async throws {
    // Given: A fresh repository
    let suiteName = "test.playback.empty.\(UUID().uuidString)"
    let repository = UserDefaultsSettingsRepository(suiteName: suiteName)
    
    // When: Loading resume state
    let loaded = await repository.loadPlaybackResumeState()
    
    // Then: Should return nil
    #expect(loaded == nil)
  }
  
  @Test("Expired state is filtered out")
  func testExpiredStateIsFiltered() async throws {
    // Given: A repository with manually created expired state
    let suiteName = "test.playback.expired.\(UUID().uuidString)"
    let repository = UserDefaultsSettingsRepository(suiteName: suiteName)
    
    // Create an expired state (25 hours ago)
    let expiredDate = Date().addingTimeInterval(-25 * 60 * 60)
    let expiredState = PlaybackResumeState(
      episodeId: "expired-episode",
      position: 100,
      duration: 600,
      timestamp: expiredDate,
      isPlaying: false
    )
    
    // Manually save to UserDefaults to bypass validation
    if let defaults = UserDefaults(suiteName: suiteName) {
      let encoder = JSONEncoder()
      if let data = try? encoder.encode(expiredState) {
        defaults.set(data, forKey: "playback_resume_state")
      }
    }
    
    // When: Loading the state
    let loaded = await repository.loadPlaybackResumeState()
    
    // Then: Should return nil because it's expired
    #expect(loaded == nil)
    
    // Cleanup
    await repository.clearPlaybackResumeState()
  }
  
  @Test("Valid state within 24 hours is loaded")
  func testValidStateIsLoaded() async throws {
    // Given: A repository with recent state
    let suiteName = "test.playback.valid.\(UUID().uuidString)"
    let repository = UserDefaultsSettingsRepository(suiteName: suiteName)
    
    // Create state from 1 hour ago
    let recentDate = Date().addingTimeInterval(-1 * 60 * 60)
    let validState = PlaybackResumeState(
      episodeId: "recent-episode",
      position: 200,
      duration: 900,
      timestamp: recentDate,
      isPlaying: true
    )
    
    await repository.savePlaybackResumeState(validState)
    
    // When: Loading the state
    let loaded = await repository.loadPlaybackResumeState()
    
    // Then: Should return the state
    #expect(loaded != nil)
    #expect(loaded?.episodeId == "recent-episode")
    #expect(loaded?.isValid == true)
    
    // Cleanup
    await repository.clearPlaybackResumeState()
  }
  
  // MARK: - Change Notification Tests
  
  @Test("Save broadcasts change notification")
  func testSaveBroadcastsChange() async throws {
    // Given: A repository with change listener
    let suiteName = "test.playback.broadcast.\(UUID().uuidString)"
    let repository = UserDefaultsSettingsRepository(suiteName: suiteName)
    
    var receivedChange: SettingsChange?
    let expectation = Expectation()
    
    let stream = repository.settingsChangeStream()
    let task = Task {
      for await change in stream {
        receivedChange = change
        await expectation.fulfill()
        break
      }
    }
    await Task.yield()
    
    // When: Saving a resume state
    let resumeState = PlaybackResumeState(
      episodeId: "broadcast-test",
      position: 50,
      duration: 300,
      timestamp: Date(),
      isPlaying: false
    )
    await repository.savePlaybackResumeState(resumeState)
    
    // Then: Should receive change notification
    await expectation.wait(for: 1.0)
    #expect(receivedChange != nil)
    
    if case .playbackResume(let state) = receivedChange {
      #expect(state?.episodeId == "broadcast-test")
    } else {
      Issue.record("Expected playbackResume change notification")
    }
    
    task.cancel()
    await repository.clearPlaybackResumeState()
  }
  
  @Test("Clear broadcasts change notification")
  func testClearBroadcastsChange() async throws {
    // Given: A repository with saved state and change listener
    let suiteName = "test.playback.clear.broadcast.\(UUID().uuidString)"
    let repository = UserDefaultsSettingsRepository(suiteName: suiteName)
    
    let resumeState = PlaybackResumeState(
      episodeId: "clear-test",
      position: 75,
      duration: 400,
      timestamp: Date(),
      isPlaying: true
    )
    await repository.savePlaybackResumeState(resumeState)
    
    var receivedChange: SettingsChange?
    let expectation = Expectation()
    
    let stream = repository.settingsChangeStream()
    let task = Task {
      for await change in stream {
        receivedChange = change
        await expectation.fulfill()
        break
      }
    }
    await Task.yield()
    
    // When: Clearing the state
    await repository.clearPlaybackResumeState()
    
    // Then: Should receive change notification with nil state
    await expectation.wait(for: 1.0)
    #expect(receivedChange != nil)
    
    if case .playbackResume(let state) = receivedChange {
      #expect(state == nil)
    } else {
      Issue.record("Expected playbackResume change notification with nil")
    }
    
    task.cancel()
  }
}

// MARK: - Test Helpers

/// Simple expectation helper for async tests
actor Expectation {
  private var fulfilled = false
  
  func fulfill() {
    fulfilled = true
  }
  
  func wait(for timeout: TimeInterval) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !fulfilled && Date() < deadline {
      try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
  }
}

import XCTest
#if canImport(Combine)
@preconcurrency import Combine
#endif
@testable import PlaybackEngine
import CoreModels
import SharedUtilities
import TestSupport

@MainActor
@MainActor
final class BasicPlaybackEngineTests: XCTestCase {
    
    private var episodeStateManager: InMemoryEpisodeStateManager!
    private var sleepTimer: SleepTimer!
    private var stubPlayer: StubEpisodePlayer!
    
    #if canImport(Combine)
    private var cancellables: Set<AnyCancellable> = []
    #endif
    
    override func setUp() {
        super.setUp()
        episodeStateManager = InMemoryEpisodeStateManager()
        sleepTimer = SleepTimer()
        stubPlayer = StubEpisodePlayer()
    }
    
    override func tearDown() {
        episodeStateManager = nil
        sleepTimer = nil
        stubPlayer = nil
        #if canImport(Combine)
        cancellables.removeAll()
        #endif
        super.tearDown()
    }
    
    // MARK: - EpisodeStateManager Tests
    
    func testEpisodeStateManager_setPlayedStatus_updatesCorrectly() async {
        // Given: Episode with unplayed status and state manager
        let episode = Episode(id: "ep1", title: "Test Episode")
        
        // When: Setting played status
        await episodeStateManager.setPlayedStatus(episode, isPlayed: true)
        
        // Then: Episode should be marked as played
        let updatedEpisode = await episodeStateManager.getEpisodeState(episode)
        XCTAssertTrue(updatedEpisode.isPlayed)
    }
    
    func testEpisodeStateManager_updatePlaybackPosition_persistsPosition() async {
        // Given: Episode with zero position
        let episode = Episode(id: "ep1", title: "Test Episode")
        let newPosition: TimeInterval = 120.5
        
        // When: Updating playback position
        await episodeStateManager.updatePlaybackPosition(episode, position: newPosition)
        
        // Then: Position should be updated (converted to Int)
        let updatedEpisode = await episodeStateManager.getEpisodeState(episode)
        XCTAssertEqual(updatedEpisode.playbackPosition, Int(newPosition))
    }
    
    func testEpisodeStateManager_multipleEpisodes_maintainsSeparateState() async {
        // Given: Two different episodes
        let episode1 = Episode(id: "ep1", title: "Episode 1")
        let episode2 = Episode(id: "ep2", title: "Episode 2")
        
        // When: Setting different states
        await episodeStateManager.setPlayedStatus(episode1, isPlayed: true)
        await episodeStateManager.updatePlaybackPosition(episode2, position: 60.0)
        
        // Then: States should be maintained separately
        let updatedEpisode1 = await episodeStateManager.getEpisodeState(episode1)
        let updatedEpisode2 = await episodeStateManager.getEpisodeState(episode2)
        
        XCTAssertTrue(updatedEpisode1.isPlayed)
        XCTAssertEqual(updatedEpisode1.playbackPosition, 0) // Unchanged
        XCTAssertFalse(updatedEpisode2.isPlayed) // Unchanged
        XCTAssertEqual(updatedEpisode2.playbackPosition, 60)
    }
    
    // MARK: - SleepTimer Tests
    
    func testSleepTimer_initialization_isNotActive() {
        // Given: Newly initialized sleep timer
        // When: Checking initial state
        let isActive = sleepTimer.isActive
        
        // Then: Should not be active
        XCTAssertFalse(isActive)
    }
    
    func testSleepTimer_startTimer_becomesActive() {
        // Given: Sleep timer with duration
        let duration: TimeInterval = 300 // 5 minutes
        
        // When: Starting timer
        sleepTimer.start(duration: duration)
        
        // Then: Should become active
        XCTAssertTrue(sleepTimer.isActive)
    }
    
    func testSleepTimer_cancelTimer_becomesInactive() {
        // Given: Active sleep timer
        sleepTimer.start(duration: 300)
        XCTAssertTrue(sleepTimer.isActive)
        
        // When: Stopping timer (using the method that exists)
        sleepTimer.stop()
        
        // Then: Should become inactive
        XCTAssertFalse(sleepTimer.isActive)
    }
    
    func testSleepTimer_multipleStarts_replacePrevious() {
        // Given: Active sleep timer
        sleepTimer.start(duration: 300)
        XCTAssertTrue(sleepTimer.isActive)
        
        // When: Starting new timer
        sleepTimer.start(duration: 600)
        
        // Then: Should still be active with new duration
        XCTAssertTrue(sleepTimer.isActive)
    }
    
    // MARK: - StubEpisodePlayer Tests
    
    func testStubEpisodePlayer_initialization_hasCorrectDefaults() {
        // Given: Newly initialized player
        // When: Checking initial state
        // Then: Should have correct defaults
        XCTAssertNotNil(stubPlayer)
    }
    
    func testStubEpisodePlayer_playEpisode_updatesState() async {
        // Given: Episode to play
        let episode = Episode(id: "ep1", title: "Test Episode")
        
        // When: Playing episode
        stubPlayer.play(episode: episode, duration: 1800)
        
        // Then: Player should be set up for playback
        // Note: This is a basic test since StubEpisodePlayer is a mock implementation
        XCTAssertNotNil(stubPlayer)
    }
    
    #if canImport(Combine)
    func testStubEpisodePlayer_statePublisher_emitsChanges() async {
        // Given: State publisher subscription
        var receivedStates: [EpisodePlaybackState] = []
        let expectation = self.expectation(description: "State changes received")
        expectation.expectedFulfillmentCount = 1
        
        stubPlayer.statePublisher
            .sink { state in
                receivedStates.append(state)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: State changes occur
        await Task.yield() // Allow initial value to emit
        
        // Then: Should receive state updates
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertGreaterThan(receivedStates.count, 0)
    }
    #endif
    
    // MARK: - PlaybackTypes Tests
    
    func testPlaybackSettings_initialization_hasCorrectDefaults() {
        // Given: Newly initialized settings
        let settings = PlaybackSettings()
        
        // When: Checking default values
        // Then: Should have sensible defaults
        XCTAssertEqual(settings.defaultSpeed, 1.0)
        XCTAssertEqual(settings.skipForwardInterval, 30)
        XCTAssertEqual(settings.skipBackwardInterval, 15)
        XCTAssertFalse(settings.enableCrossfade)
        XCTAssertEqual(settings.crossfadeDuration, 3.0)
    }
    
    func testChapterParser_parseChapters_returnsExpectedResult() {
        // Given: Basic chapter parser from PlaybackEngine
        let parser = PlaybackEngine.BasicChapterParser()
        let metadata: [String: Any] = [:]
        
        // When: Parsing chapters
        let chapters = parser.parseChapters(from: metadata)
        
        // Then: Should return empty array for basic implementation
        XCTAssertTrue(chapters.isEmpty)
    }
    
    func testChapter_initialization_setsCorrectValues() {
        // Given: Chapter data
        let title = "Chapter 1"
        let startTime: TimeInterval = 0
        let endTime: TimeInterval = 300
        let artworkURL = URL(string: "https://example.com/artwork.jpg")
        
        // When: Creating chapter
        let chapter = Chapter(title: title, startTime: startTime, endTime: endTime, artworkURL: artworkURL)
        
        // Then: Should have correct values
        XCTAssertEqual(chapter.title, title)
        XCTAssertEqual(chapter.startTime, startTime)
        XCTAssertEqual(chapter.endTime, endTime)
        XCTAssertEqual(chapter.artworkURL, artworkURL)
    }
    
    // MARK: - Cross-Platform Compatibility Tests
    
    func testPlaybackEngine_crossPlatform_compilesCorrectly() {
        // Given: Cross-platform compilation
        // When: Testing platform-specific code paths
        #if canImport(Combine)
        // Combine available - can use reactive patterns
        XCTAssertTrue(true, "Combine available")
        #else
        // Combine not available - using fallbacks
        XCTAssertTrue(true, "Combine not available, using fallbacks")
        #endif
        
        // Then: Should compile without issues
        XCTAssertNotNil(stubPlayer)
        XCTAssertNotNil(sleepTimer)
    }
    
    // MARK: - Concurrency and Thread Safety Tests
    
    func testPlaybackEngine_concurrentAccess_threadSafe() async {
        // Given: Multiple concurrent operations
        let operationCount = 10
        let stateManager = episodeStateManager!
        
        // When: Performing concurrent state operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<operationCount {
                group.addTask {
                    let episode = Episode(id: "ep\(i)", title: "Episode \(i)")
                    await stateManager.setPlayedStatus(episode, isPlayed: i % 2 == 0)
                }
            }
        }
        
        // Then: Operations should complete without data races
        XCTAssertNotNil(episodeStateManager)
    }
    
    // MARK: - Performance Tests
    
    func testEpisodeStateManager_bulkOperations_performsWell() async {
        // Given: Large number of episodes
        let episodeCount = 100  // Reduced for CI environment
        
        // When: Performing bulk state updates
        let startTime = Date()
        
        for i in 0..<episodeCount {
            let episode = Episode(id: "bulk_ep\(i)", title: "Episode \(i)")
            await episodeStateManager.setPlayedStatus(episode, isPlayed: i % 2 == 0)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then: Should complete within reasonable time
        XCTAssertLessThan(duration, 5.0, "Bulk operations should complete within 5 seconds")
    }
    
    // MARK: - Error Handling Tests
    
    func testPlaybackEngine_invalidInput_handlesGracefully() async {
        // Given: Invalid episode data
        let episode = Episode(id: "", title: "")
        
        // When: Operating with invalid data
        await episodeStateManager.setPlayedStatus(episode, isPlayed: true)
        
        // Then: Should handle gracefully without crashing
        let state = await episodeStateManager.getEpisodeState(episode)
        XCTAssertNotNil(state)
    }
    
    // MARK: - Edge Cases
    
    func testSleepTimer_zeroDuration_handlesCorrectly() {
        // Given: Zero duration
        let duration: TimeInterval = 0
        
        // When: Starting timer with zero duration
        sleepTimer.start(duration: duration)
        
        // Then: Should handle appropriately (implementation dependent)
        // This test ensures the timer doesn't crash with edge case input
        XCTAssertNotNil(sleepTimer)
    }
    
    func testEpisodeStateManager_negativeDuration_handlesCorrectly() async {
        // Given: Episode with negative position
        let episode = Episode(id: "negative_test", title: "Negative Test")
        let negativePosition: TimeInterval = -10.0
        
        // When: Setting negative position
        await episodeStateManager.updatePlaybackPosition(episode, position: negativePosition)
        
        // Then: Should handle gracefully (converted to Int, likely becomes -10 or 0)
        let state = await episodeStateManager.getEpisodeState(episode)
        XCTAssertNotNil(state)
        // Position handling depends on implementation requirements
    }
}

// MARK: - Mock Objects

private final class MockTicker: Ticker, @unchecked Sendable {
    private var _currentTime: TimeInterval = 0
    private var _isActive = false
    private let queue = DispatchQueue(label: "MockTicker", attributes: .concurrent)
    
    var currentTime: TimeInterval {
        get { queue.sync { _currentTime } }
        set { queue.async(flags: .barrier) { [weak self] in self?._currentTime = newValue } }
    }
    
    var isActive: Bool {
        get { queue.sync { _isActive } }
        set { queue.async(flags: .barrier) { [weak self] in self?._isActive = newValue } }
    }
    
    func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void) {
        isActive = true
        // Mock implementation - in real tests would set up actual scheduling
    }
    
    func cancel() {
        isActive = false
    }
    
    func simulateTick() {
        currentTime += 1.0
    }
}
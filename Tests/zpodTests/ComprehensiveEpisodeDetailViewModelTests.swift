import XCTest
#if canImport(Combine)
@preconcurrency import Combine
#endif
@testable import zpodLib

/// Comprehensive unit tests for EpisodeDetailViewModel testing playback integration and UI state management
@MainActor
final class ComprehensiveEpisodeDetailViewModelTests: XCTestCase {
    
    // MARK: - Properties
    private var viewModel: EpisodeDetailViewModel!
    private var mockPlaybackService: MockEpisodePlaybackService!
    private var mockSleepTimer: MockSleepTimer!
    private var cancellables: Set<AnyCancellable>!
    private var sampleEpisode: Episode!
    private var episodeWithChapters: Episode!
    
    // MARK: - Test Doubles
    
    /// Mock playback service for testing
    private final class MockEpisodePlaybackService: EpisodePlaybackService, @unchecked Sendable {
        private let stateSubject = CurrentValueSubject<EpisodePlaybackState, Never>(.idle(nil))
        
        var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
            stateSubject.eraseToAnyPublisher()
        }
        
        private(set) var lastPlayedEpisode: Episode?
        private(set) var lastPlayedDuration: TimeInterval?
        private(set) var isPlaying = false
        
        func play(episode: Episode, duration: TimeInterval) {
            lastPlayedEpisode = episode
            lastPlayedDuration = duration
            isPlaying = true
            stateSubject.send(.playing(episode, position: 0, duration: duration))
        }
        
        func pause() {
            isPlaying = false
            if case .playing(let episode, let position, let duration) = stateSubject.value {
                stateSubject.send(.paused(episode, position: position, duration: duration))
            }
        }
        
        func stop() {
            isPlaying = false
            stateSubject.send(.idle(nil))
        }
        
        // Simulation methods for testing
        func simulateProgress(position: TimeInterval) {
            if case .playing(let episode, _, let duration) = stateSubject.value {
                stateSubject.send(.playing(episode, position: position, duration: duration))
            }
        }
        
        func simulateFinished() {
            if case .playing(let episode, _, let duration) = stateSubject.value {
                stateSubject.send(.finished(episode, duration: duration))
                isPlaying = false
            }
        }
    }
    
    /// Enhanced mock playback service for testing advanced controls
    private final class MockEnhancedEpisodePlayer: MockEpisodePlaybackService, EnhancedEpisodePlayer {
        private(set) var skipForwardCalled = false
        private(set) var skipBackwardCalled = false
        private(set) var seekPosition: TimeInterval?
        private(set) var playbackSpeed: Float = 1.0
        private(set) var jumpedToChapter: Chapter?
        private(set) var markedAsPlayed: Bool?
        
        func skipForward() {
            skipForwardCalled = true
        }
        
        func skipBackward() {
            skipBackwardCalled = true
        }
        
        func seek(to position: TimeInterval) {
            seekPosition = position
        }
        
        func setPlaybackSpeed(_ speed: Float) {
            playbackSpeed = speed
        }
        
        func jumpToChapter(_ chapter: Chapter) {
            jumpedToChapter = chapter
        }
        
        func markEpisodeAs(played: Bool) {
            markedAsPlayed = played
        }
        
        func getCurrentPlaybackSpeed() -> Float {
            return playbackSpeed
        }
    }
    
    /// Mock sleep timer for testing
    private final class MockSleepTimer: SleepTimer, @unchecked Sendable {
        private(set) var isActive = false
        private(set) var remainingTime: TimeInterval = 0
        private(set) var startedWithDuration: TimeInterval?
        private(set) var stopCalled = false
        private(set) var resetCalled = false
        
        func start(duration: TimeInterval) {
            startedWithDuration = duration
            isActive = true
            remainingTime = duration
        }
        
        func stop() {
            stopCalled = true
            isActive = false
            remainingTime = 0
        }
        
        func reset() {
            resetCalled = true
            remainingTime = 0
        }
        
        // Simulation methods for testing
        func simulateProgress(remaining: TimeInterval) {
            remainingTime = remaining
        }
        
        func simulateExpired() {
            isActive = false
            remainingTime = 0
        }
    }
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Given: Clean test environment
        mockPlaybackService = MockEpisodePlaybackService()
        mockSleepTimer = MockSleepTimer()
        cancellables = Set<AnyCancellable>()
        
        // Create test episodes
        sampleEpisode = Episode(
            id: "episode1",
            title: "Test Episode",
            description: "A test episode for unit testing",
            mediaURL: URL(string: "https://example.com/episode1.mp3")!,
            duration: 1800, // 30 minutes
            chapters: []
        )
        
        episodeWithChapters = Episode(
            id: "episode2",
            title: "Episode with Chapters",
            description: "Episode containing chapter markers",
            mediaURL: URL(string: "https://example.com/episode2.mp3")!,
            duration: 3600, // 60 minutes
            chapters: [
                Chapter(id: "ch1", title: "Introduction", startTime: 0),
                Chapter(id: "ch2", title: "Main Content", startTime: 600), // 10 minutes
                Chapter(id: "ch3", title: "Discussion", startTime: 2400), // 40 minutes
                Chapter(id: "ch4", title: "Conclusion", startTime: 3300) // 55 minutes
            ]
        )
        
        viewModel = EpisodeDetailViewModel(
            playbackService: mockPlaybackService,
            sleepTimer: mockSleepTimer
        )
    }
    
    override func tearDown() async throws {
        cancellables?.removeAll()
        viewModel = nil
        mockPlaybackService = nil
        mockSleepTimer = nil
        sampleEpisode = nil
        episodeWithChapters = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_DefaultState() {
        // Given: Fresh view model
        
        // Then: Should have default values
        XCTAssertNil(viewModel.episode)
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(viewModel.currentPosition, 0)
        XCTAssertEqual(viewModel.progressFraction, 0)
        XCTAssertEqual(viewModel.formattedCurrentTime, "0:00")
        XCTAssertEqual(viewModel.formattedDuration, "0:00")
        XCTAssertEqual(viewModel.playbackSpeed, 1.0)
        XCTAssertTrue(viewModel.chapters.isEmpty)
        XCTAssertNil(viewModel.currentChapter)
    }
    
    func testInitialization_WithDefaultServices() {
        // Given: View model with default services
        
        // When: Creating view model without explicit services
        let defaultViewModel = EpisodeDetailViewModel()
        
        // Then: Should initialize successfully
        XCTAssertNotNil(defaultViewModel)
        XCTAssertFalse(defaultViewModel.isPlaying)
        XCTAssertEqual(defaultViewModel.playbackSpeed, 1.0)
    }
    
    // MARK: - Episode Loading Tests
    
    func testLoadEpisode_BasicEpisode() {
        // Given: Episode without chapters
        
        // When: Loading episode
        viewModel.loadEpisode(sampleEpisode)
        
        // Then: Episode should be loaded with correct data
        XCTAssertEqual(viewModel.episode?.id, sampleEpisode.id)
        XCTAssertEqual(viewModel.episode?.title, sampleEpisode.title)
        XCTAssertTrue(viewModel.chapters.isEmpty)
        XCTAssertNil(viewModel.currentChapter)
    }
    
    func testLoadEpisode_WithChapters() {
        // Given: Episode with chapters
        
        // When: Loading episode
        viewModel.loadEpisode(episodeWithChapters)
        
        // Then: Chapters should be loaded
        XCTAssertEqual(viewModel.episode?.id, episodeWithChapters.id)
        XCTAssertEqual(viewModel.chapters.count, 4)
        XCTAssertEqual(viewModel.chapters[0].title, "Introduction")
        XCTAssertEqual(viewModel.chapters[1].title, "Main Content")
    }
    
    func testLoadEpisode_ResetsState() {
        // Given: View model with existing episode and state
        viewModel.loadEpisode(sampleEpisode)
        mockPlaybackService.play(episode: sampleEpisode, duration: 1800)
        
        // Wait for state update
        let expectation = XCTestExpectation(description: "State update")
        viewModel.$isPlaying
            .dropFirst()
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
        
        // When: Loading new episode
        viewModel.loadEpisode(episodeWithChapters)
        
        // Then: State should be updated for new episode
        XCTAssertEqual(viewModel.episode?.id, episodeWithChapters.id)
        XCTAssertEqual(viewModel.chapters.count, 4)
    }
    
    // MARK: - Playback Control Tests
    
    func testPlayPause_StartPlayback() {
        // Given: Loaded episode, not playing
        viewModel.loadEpisode(sampleEpisode)
        XCTAssertFalse(viewModel.isPlaying)
        
        // When: Calling play/pause
        viewModel.playPause()
        
        // Then: Should start playback
        XCTAssertEqual(mockPlaybackService.lastPlayedEpisode?.id, sampleEpisode.id)
        XCTAssertEqual(mockPlaybackService.lastPlayedDuration, 1800)
        XCTAssertTrue(mockPlaybackService.isPlaying)
    }
    
    func testPlayPause_PausePlayback() async {
        // Given: Episode playing
        viewModel.loadEpisode(sampleEpisode)
        viewModel.playPause() // Start playing
        
        // Wait for playing state
        let playingExpectation = XCTestExpectation(description: "Playing state")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if isPlaying { playingExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [playingExpectation], timeout: 1.0)
        
        // When: Calling play/pause again
        viewModel.playPause()
        
        // Then: Should pause playback
        XCTAssertFalse(mockPlaybackService.isPlaying)
    }
    
    func testPlayPause_NoEpisodeLoaded() {
        // Given: No episode loaded
        XCTAssertNil(viewModel.episode)
        
        // When: Calling play/pause
        viewModel.playPause()
        
        // Then: Should not attempt playback
        XCTAssertNil(mockPlaybackService.lastPlayedEpisode)
        XCTAssertFalse(mockPlaybackService.isPlaying)
    }
    
    func testPlayPause_EpisodeWithNilDuration() {
        // Given: Episode with nil duration
        let episodeNoDuration = Episode(
            id: "no-duration",
            title: "No Duration Episode",
            description: "Episode without duration",
            mediaURL: URL(string: "https://example.com/noduration.mp3")!,
            duration: nil
        )
        viewModel.loadEpisode(episodeNoDuration)
        
        // When: Starting playback
        viewModel.playPause()
        
        // Then: Should use default duration
        XCTAssertEqual(mockPlaybackService.lastPlayedDuration, 300.0) // 5 minutes default
    }
    
    // MARK: - Enhanced Controls Tests (with Enhanced Player)
    
    func testEnhancedControls_WithEnhancedPlayer() {
        // Given: View model with enhanced player
        let mockEnhancedPlayer = MockEnhancedEpisodePlayer()
        let enhancedViewModel = EpisodeDetailViewModel(
            playbackService: mockEnhancedPlayer,
            sleepTimer: mockSleepTimer
        )
        enhancedViewModel.loadEpisode(sampleEpisode)
        
        // When: Using enhanced controls
        enhancedViewModel.skipForward()
        enhancedViewModel.skipBackward()
        enhancedViewModel.seek(to: 120.0)
        enhancedViewModel.setPlaybackSpeed(1.5)
        enhancedViewModel.markAsPlayed(true)
        
        // Then: Enhanced player methods should be called
        XCTAssertTrue(mockEnhancedPlayer.skipForwardCalled)
        XCTAssertTrue(mockEnhancedPlayer.skipBackwardCalled)
        XCTAssertEqual(mockEnhancedPlayer.seekPosition, 120.0)
        XCTAssertEqual(mockEnhancedPlayer.playbackSpeed, 1.5)
        XCTAssertEqual(mockEnhancedPlayer.markedAsPlayed, true)
        XCTAssertEqual(enhancedViewModel.playbackSpeed, 1.5)
    }
    
    func testEnhancedControls_WithBasicPlayer() {
        // Given: View model with basic player (no enhanced features)
        viewModel.loadEpisode(sampleEpisode)
        
        // When: Attempting to use enhanced controls
        viewModel.skipForward()
        viewModel.skipBackward()
        viewModel.seek(to: 120.0)
        viewModel.setPlaybackSpeed(1.5)
        viewModel.markAsPlayed(true)
        
        // Then: Should not crash (methods should handle nil enhanced player gracefully)
        // Note: With basic player, these are no-ops, but speed should still be updated
        XCTAssertEqual(viewModel.playbackSpeed, 1.5)
    }
    
    func testJumpToChapter_WithEnhancedPlayer() {
        // Given: Enhanced player with chapter episode
        let mockEnhancedPlayer = MockEnhancedEpisodePlayer()
        let enhancedViewModel = EpisodeDetailViewModel(
            playbackService: mockEnhancedPlayer,
            sleepTimer: mockSleepTimer
        )
        enhancedViewModel.loadEpisode(episodeWithChapters)
        
        // When: Jumping to chapter
        let targetChapter = episodeWithChapters.chapters[1]
        enhancedViewModel.jumpToChapter(targetChapter)
        
        // Then: Enhanced player should jump to chapter
        XCTAssertEqual(mockEnhancedPlayer.jumpedToChapter?.id, targetChapter.id)
        XCTAssertEqual(mockEnhancedPlayer.jumpedToChapter?.title, "Main Content")
    }
    
    // MARK: - Sleep Timer Tests
    
    func testSleepTimer_StartTimer() {
        // Given: Sleep timer ready
        
        // When: Starting sleep timer
        viewModel.startSleepTimer(duration: 1800) // 30 minutes
        
        // Then: Sleep timer should be started
        XCTAssertEqual(mockSleepTimer.startedWithDuration, 1800)
        XCTAssertTrue(mockSleepTimer.isActive)
        XCTAssertTrue(viewModel.sleepTimerActive)
    }
    
    func testSleepTimer_StopTimer() {
        // Given: Active sleep timer
        viewModel.startSleepTimer(duration: 1800)
        XCTAssertTrue(mockSleepTimer.isActive)
        
        // When: Stopping sleep timer
        viewModel.stopSleepTimer()
        
        // Then: Sleep timer should be stopped
        XCTAssertTrue(mockSleepTimer.stopCalled)
    }
    
    func testSleepTimer_ResetTimer() {
        // Given: Sleep timer with remaining time
        viewModel.startSleepTimer(duration: 1800)
        mockSleepTimer.simulateProgress(remaining: 900)
        
        // When: Resetting sleep timer
        viewModel.resetSleepTimer()
        
        // Then: Sleep timer should be reset
        XCTAssertTrue(mockSleepTimer.resetCalled)
    }
    
    func testSleepTimer_RemainingTime() {
        // Given: Active sleep timer
        viewModel.startSleepTimer(duration: 1800)
        mockSleepTimer.simulateProgress(remaining: 1200)
        
        // When: Checking remaining time
        let remainingTime = viewModel.sleepTimerRemainingTime
        
        // Then: Should return correct remaining time
        XCTAssertEqual(remainingTime, 1200)
    }
    
    // MARK: - Playback State Integration Tests
    
    func testPlaybackStateUpdates_IdleState() async {
        // Given: View model observing playback state
        viewModel.loadEpisode(sampleEpisode)
        
        // When: Playback service reports idle state
        mockPlaybackService.stop()
        
        // Wait for state update
        let expectation = XCTestExpectation(description: "Idle state update")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if !isPlaying { expectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
        
        // Then: UI should reflect idle state
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(viewModel.currentPosition, 0)
        XCTAssertEqual(viewModel.progressFraction, 0)
        XCTAssertEqual(viewModel.formattedCurrentTime, "0:00")
        XCTAssertEqual(viewModel.formattedDuration, "0:00")
    }
    
    func testPlaybackStateUpdates_PlayingState() async {
        // Given: View model with loaded episode
        viewModel.loadEpisode(sampleEpisode)
        
        // When: Playback service reports playing state
        mockPlaybackService.play(episode: sampleEpisode, duration: 1800)
        
        // Wait for state update
        let expectation = XCTestExpectation(description: "Playing state update")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if isPlaying { expectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
        
        // Then: UI should reflect playing state
        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertEqual(viewModel.formattedDuration, "30:00")
    }
    
    func testPlaybackStateUpdates_PausedState() async {
        // Given: Playing episode
        viewModel.loadEpisode(sampleEpisode)
        mockPlaybackService.play(episode: sampleEpisode, duration: 1800)
        
        // Wait for playing state
        let playingExpectation = XCTestExpectation(description: "Playing state")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if isPlaying { playingExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [playingExpectation], timeout: 1.0)
        
        // When: Pausing playback
        mockPlaybackService.pause()
        
        // Wait for paused state
        let pausedExpectation = XCTestExpectation(description: "Paused state")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if !isPlaying { pausedExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [pausedExpectation], timeout: 1.0)
        
        // Then: UI should reflect paused state
        XCTAssertFalse(viewModel.isPlaying)
    }
    
    func testPlaybackStateUpdates_FinishedState() async {
        // Given: Playing episode
        viewModel.loadEpisode(sampleEpisode)
        mockPlaybackService.play(episode: sampleEpisode, duration: 1800)
        
        // Wait for playing state
        let playingExpectation = XCTestExpectation(description: "Playing state")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if isPlaying { playingExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [playingExpectation], timeout: 1.0)
        
        // When: Episode finishes
        mockPlaybackService.simulateFinished()
        
        // Wait for finished state
        let finishedExpectation = XCTestExpectation(description: "Finished state")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if !isPlaying { finishedExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [finishedExpectation], timeout: 1.0)
        
        // Then: UI should reflect finished state
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(viewModel.currentPosition, 1800) // Should be at end
        XCTAssertEqual(viewModel.progressFraction, 1.0) // 100% progress
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProgressTracking_UpdatesCorrectly() async {
        // Given: Playing episode
        viewModel.loadEpisode(sampleEpisode)
        mockPlaybackService.play(episode: sampleEpisode, duration: 1800)
        
        // Wait for initial playing state
        let playingExpectation = XCTestExpectation(description: "Playing state")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if isPlaying { playingExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [playingExpectation], timeout: 1.0)
        
        // When: Simulating progress
        mockPlaybackService.simulateProgress(position: 900) // 15 minutes
        
        // Wait for progress update
        let progressExpectation = XCTestExpectation(description: "Progress update")
        viewModel.$currentPosition
            .dropFirst()
            .sink { position in
                if position == 900 { progressExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [progressExpectation], timeout: 1.0)
        
        // Then: Progress should be updated correctly
        XCTAssertEqual(viewModel.currentPosition, 900)
        XCTAssertEqual(viewModel.progressFraction, 0.5, accuracy: 0.01) // 50%
        XCTAssertEqual(viewModel.formattedCurrentTime, "15:00")
        XCTAssertEqual(viewModel.formattedDuration, "30:00")
    }
    
    func testProgressTracking_EdgeCases() async {
        // Given: Episode with progress at edge cases
        viewModel.loadEpisode(sampleEpisode)
        mockPlaybackService.play(episode: sampleEpisode, duration: 1800)
        
        // Wait for playing state
        let playingExpectation = XCTestExpectation(description: "Playing state")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if isPlaying { playingExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [playingExpectation], timeout: 1.0)
        
        // When: Progress beyond duration (edge case)
        mockPlaybackService.simulateProgress(position: 2000) // Beyond 1800 duration
        
        // Wait for progress update
        let progressExpectation = XCTestExpectation(description: "Progress update")
        viewModel.$currentPosition
            .dropFirst()
            .sink { position in
                if position == 2000 { progressExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [progressExpectation], timeout: 1.0)
        
        // Then: Progress fraction should be clamped to 1.0
        XCTAssertEqual(viewModel.progressFraction, 1.0) // Clamped to 100%
        XCTAssertEqual(viewModel.formattedCurrentTime, "33:20") // Still shows actual time
    }
    
    // MARK: - Chapter Navigation Tests
    
    func testChapterNavigation_CurrentChapterUpdates() async {
        // Given: Episode with chapters
        viewModel.loadEpisode(episodeWithChapters)
        mockPlaybackService.play(episode: episodeWithChapters, duration: 3600)
        
        // Wait for playing state
        let playingExpectation = XCTestExpectation(description: "Playing state")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if isPlaying { playingExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [playingExpectation], timeout: 1.0)
        
        // When: Progress to second chapter
        mockPlaybackService.simulateProgress(position: 1200) // 20 minutes
        
        // Wait for position update
        let positionExpectation = XCTestExpectation(description: "Position update")
        viewModel.$currentPosition
            .dropFirst()
            .sink { position in
                if position == 1200 { positionExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [positionExpectation], timeout: 1.0)
        
        // Then: Current chapter should be updated
        XCTAssertEqual(viewModel.currentChapter?.title, "Main Content")
        XCTAssertEqual(viewModel.currentChapter?.startTime, 600)
    }
    
    func testChapterNavigation_LastChapter() async {
        // Given: Episode with chapters
        viewModel.loadEpisode(episodeWithChapters)
        mockPlaybackService.play(episode: episodeWithChapters, duration: 3600)
        
        // Wait for playing state
        let playingExpectation = XCTestExpectation(description: "Playing state")
        viewModel.$isPlaying
            .dropFirst()
            .sink { isPlaying in
                if isPlaying { playingExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [playingExpectation], timeout: 1.0)
        
        // When: Progress to last chapter
        mockPlaybackService.simulateProgress(position: 3400) // 56:40 - in conclusion chapter
        
        // Wait for position update
        let positionExpectation = XCTestExpectation(description: "Position update")
        viewModel.$currentPosition
            .dropFirst()
            .sink { position in
                if position == 3400 { positionExpectation.fulfill() }
            }
            .store(in: &cancellables)
        wait(for: [positionExpectation], timeout: 1.0)
        
        // Then: Should be in conclusion chapter
        XCTAssertEqual(viewModel.currentChapter?.title, "Conclusion")
        XCTAssertEqual(viewModel.currentChapter?.startTime, 3300)
    }
    
    func testChapterNavigation_NoChapters() {
        // Given: Episode without chapters
        viewModel.loadEpisode(sampleEpisode)
        
        // Then: Current chapter should be nil
        XCTAssertNil(viewModel.currentChapter)
        XCTAssertTrue(viewModel.chapters.isEmpty)
    }
    
    // MARK: - Time Formatting Tests
    
    func testTimeFormatting_VariousDurations() {
        // Given: Episodes with different durations for testing formatting
        let testCases: [(seconds: TimeInterval, expected: String)] = [
            (0, "0:00"),
            (59, "0:59"),
            (60, "1:00"),
            (125, "2:05"),
            (3661, "61:01"), // Over 1 hour
            (7200, "120:00") // 2 hours
        ]
        
        for testCase in testCases {
            // When: Episode with specific duration
            let testEpisode = Episode(
                id: "test-\(testCase.seconds)",
                title: "Test Episode",
                description: "Test",
                mediaURL: URL(string: "https://example.com/test.mp3")!,
                duration: testCase.seconds
            )
            
            viewModel.loadEpisode(testEpisode)
            mockPlaybackService.play(episode: testEpisode, duration: testCase.seconds)
            
            // Wait briefly for state update
            let expectation = XCTestExpectation(description: "Duration format")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 0.5)
            
            // Then: Duration should be formatted correctly
            XCTAssertEqual(viewModel.formattedDuration, testCase.expected, 
                          "Duration \(testCase.seconds) should format as \(testCase.expected)")
        }
    }
    
    // MARK: - Error Handling & Edge Cases
    
    func testErrorHandling_InvalidEpisodeData() {
        // Given: Episode with minimal data
        let minimalEpisode = Episode(
            id: "minimal",
            title: "",
            description: nil,
            mediaURL: URL(string: "https://example.com/minimal.mp3")!,
            duration: 0
        )
        
        // When: Loading minimal episode
        viewModel.loadEpisode(minimalEpisode)
        
        // Then: Should handle gracefully
        XCTAssertEqual(viewModel.episode?.id, "minimal")
        XCTAssertTrue(viewModel.chapters.isEmpty)
        XCTAssertNil(viewModel.currentChapter)
    }
    
    func testErrorHandling_ZeroDuration() {
        // Given: Episode with zero duration
        let zeroDurationEpisode = Episode(
            id: "zero-duration",
            title: "Zero Duration",
            description: "Episode with zero duration",
            mediaURL: URL(string: "https://example.com/zero.mp3")!,
            duration: 0
        )
        
        viewModel.loadEpisode(zeroDurationEpisode)
        
        // When: Attempting playback
        viewModel.playPause()
        
        // Then: Should use zero duration but not crash
        XCTAssertEqual(mockPlaybackService.lastPlayedDuration, 0)
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_StateUpdates() {
        // Given: Episode loaded
        viewModel.loadEpisode(episodeWithChapters)
        
        // Measure performance of state updates
        measure {
            mockPlaybackService.play(episode: episodeWithChapters, duration: 3600)
            
            // Simulate rapid progress updates
            for i in 0..<100 {
                mockPlaybackService.simulateProgress(position: TimeInterval(i * 36)) // Every 36 seconds
            }
        }
    }
    
    func testPerformance_ChapterLookup() {
        // Given: Episode with many chapters
        let manyChapters = (0..<100).map { i in
            Chapter(id: "ch\(i)", title: "Chapter \(i)", startTime: TimeInterval(i * 60))
        }
        
        let episodeWithManyChapters = Episode(
            id: "many-chapters",
            title: "Episode with Many Chapters",
            description: "Performance test episode",
            mediaURL: URL(string: "https://example.com/many.mp3")!,
            duration: 6000,
            chapters: manyChapters
        )
        
        viewModel.loadEpisode(episodeWithManyChapters)
        mockPlaybackService.play(episode: episodeWithManyChapters, duration: 6000)
        
        // Measure chapter lookup performance
        measure {
            for i in 0..<100 {
                mockPlaybackService.simulateProgress(position: TimeInterval(i * 60 + 30))
            }
        }
    }
}
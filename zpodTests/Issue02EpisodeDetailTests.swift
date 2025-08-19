#if canImport(XCTest)
  import XCTest
  #if canImport(zpod)
    @testable import zpod
  #else
    @testable import zpodLib
  #endif
  @preconcurrency import Combine

  // MARK: - Test Doubles

  final class ManualTicker: Ticker, @unchecked Sendable {
    private var tick: (() -> Void)?
    private(set) var isScheduled = false
    
    func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void) {
      // Ignore interval; manual control in tests
      self.tick = tick
      isScheduled = true
    }
    
    func cancel() {
      tick = nil
      isScheduled = false
    }
    
    func advance(by seconds: Int) {
      guard seconds > 0 else { return }
      for _ in 0..<seconds { tick?() }
    }
  }

  // Production protocols & enums now provided by EpisodePlaybackService.swift

  // Temporary stub for Episode to ensure tests compile if Episode not yet extended
  extension Episode {
    var testDefaultDuration: TimeInterval { 300 }
  }

  // MARK: - Fixture Helpers
  struct EpisodeFixture {
    static func make(id: String = "e1", title: String = "Ep 1") -> Episode {
      Episode(id: id, title: title, description: nil, mediaURL: nil)
    }
  }

  // MARK: - Tests (Red Phase)
  final class Issue02EpisodeDetailTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    // These tests define the contract the implementation must satisfy.

    @MainActor
    func testIdleToPlayingStartsAtZero() {
      let (service, ticker, episode) = makeSystem()
      var states: [EpisodePlaybackState] = []
      service.statePublisher.sink { states.append($0) }.store(in: &cancellables)

      service.play(episode: episode, duration: 10)

      guard case .playing(let ep, let position, let duration) = states.last else {
        XCTFail("Expected playing state")
        return
      }
      XCTAssertEqual(ep.id, episode.id)
      XCTAssertEqual(position, 0, accuracy: 0.0001)
      XCTAssertEqual(duration, 10)
      XCTAssertTrue(ticker.isScheduled)
    }

    @MainActor
    func testProgressIncrementsWithTicks() {
      let (service, ticker, episode) = makeSystem()
      var last: EpisodePlaybackState?
      service.statePublisher.sink { last = $0 }.store(in: &cancellables)
      service.play(episode: episode, duration: 5)
      ticker.advance(by: 3)
      guard case .playing(_, let position, _) = last else { return XCTFail("Expected playing") }
      XCTAssertEqual(position, 3, accuracy: 0.0001)
    }

    @MainActor
    func testPausePreservesPositionAndStopsAdvancing() {
      let (service, ticker, episode) = makeSystem()
      var last: EpisodePlaybackState?
      service.statePublisher.sink { last = $0 }.store(in: &cancellables)
      service.play(episode: episode, duration: 8)
      ticker.advance(by: 2)
      service.pause()
      guard case .paused(_, let pausedPos, _) = last else { return XCTFail("Expected paused") }
      let before = pausedPos
      ticker.advance(by: 2)
      guard case .paused(_, let stillPos, _) = last else {
        return XCTFail("Expected paused after advancing")
      }
      XCTAssertEqual(before, stillPos, accuracy: 0.0001)
    }

    @MainActor
    func testResumeFromPauseContinuesProgress() {
      let (service, ticker, episode) = makeSystem()
      var last: EpisodePlaybackState?
      service.statePublisher.sink { last = $0 }.store(in: &cancellables)
      service.play(episode: episode, duration: 10)
      ticker.advance(by: 4)
      service.pause()
      service.play(episode: episode, duration: 10)
      ticker.advance(by: 2)
      guard case .playing(_, let position, _) = last else {
        return XCTFail("Expected playing after resume")
      }
      XCTAssertEqual(position, 6, accuracy: 0.0001)
    }

    @MainActor
    func testFinishEmitsFinishedState() {
      let (service, ticker, episode) = makeSystem()
      var last: EpisodePlaybackState?
      service.statePublisher.sink { last = $0 }.store(in: &cancellables)
      service.play(episode: episode, duration: 4)
      ticker.advance(by: 4)
      guard case .finished(let ep, let duration) = last else { return XCTFail("Expected finished") }
      XCTAssertEqual(ep.id, episode.id)
      XCTAssertEqual(duration, 4)
    }

    @MainActor
    func testRestartAfterFinishResetsPosition() {
      let (service, ticker, episode) = makeSystem()
      var last: EpisodePlaybackState?
      service.statePublisher.sink { last = $0 }.store(in: &cancellables)
      service.play(episode: episode, duration: 3)
      ticker.advance(by: 3)
      service.play(episode: episode, duration: 3)
      guard case .playing(_, let position, _) = last else {
        return XCTFail("Expected playing after restart")
      }
      XCTAssertEqual(position, 0, accuracy: 0.0001)
    }

    @MainActor
    func testSwitchingEpisodesResetsPositionAndStartsNew() {
      let (service, ticker, episodeA) = makeSystem()
      let episodeB = EpisodeFixture.make(id: "e2", title: "Ep 2")
      var last: EpisodePlaybackState?
      service.statePublisher.sink { last = $0 }.store(in: &cancellables)
      service.play(episode: episodeA, duration: 10)
      ticker.advance(by: 5)
      service.play(episode: episodeB, duration: 7)
      guard case .playing(let current, let position, let duration) = last else {
        return XCTFail("Expected playing new episode")
      }
      XCTAssertEqual(current.id, episodeB.id)
      XCTAssertEqual(position, 0, accuracy: 0.0001)
      XCTAssertEqual(duration, 7)
    }

    @MainActor
    func testDoublePlaySameEpisodeIsNoOp() {
      let (service, ticker, episode) = makeSystem()
      var emissions = 0
      service.statePublisher.sink { _ in emissions += 1 }.store(in: &cancellables)
      service.play(episode: episode, duration: 6)
      service.play(episode: episode, duration: 6)
      ticker.advance(by: 1)
      XCTAssertGreaterThanOrEqual(emissions, 1)
    }

    // MARK: - Factory
    @MainActor
    private func makeSystem() -> (EpisodePlaybackService, ManualTicker, Episode) {
      // Placeholder stub service that will be replaced; for red phase we supply a dummy that never emits beyond idle
      let ticker = ManualTicker()
      let service = StubEpisodePlayer(initialEpisode: EpisodeFixture.make(), ticker: ticker)
      return (service, ticker, EpisodeFixture.make())
    }
  }
#endif

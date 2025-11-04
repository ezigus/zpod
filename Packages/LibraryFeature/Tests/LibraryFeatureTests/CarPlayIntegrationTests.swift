#if os(iOS)
import XCTest
import CoreModels
import PlaybackEngine
@testable import LibraryFeature

final class CarPlayIntegrationTests: XCTestCase {

  func testPodcastItemsAreAlphabetizedAndIncludeEpisodeMetadata() {
    let podcastA = makePodcast(id: "a", title: "Swift Talk", episodeCount: 2)
    let podcastB = makePodcast(id: "b", title: "Accidental Tech Podcast", episodeCount: 1)

    let items = CarPlayDataAdapter.makePodcastItems(from: [podcastA, podcastB])

    XCTAssertEqual(items.map(\.title), ["Accidental Tech Podcast", "Swift Talk"])
    XCTAssertEqual(items.first?.detailText, "1 episode")
    XCTAssertEqual(items.last?.detailText, "2 episodes")
    XCTAssertTrue(items.last?.voiceCommands.contains("Play Swift Talk") ?? false)
    XCTAssertEqual(items.last?.episodes.count, 2)
  }

  func testEpisodeItemsSortedByPubDateAndLimited() {
    var podcast = makePodcast(id: "swift", title: "Swift Talk", episodeCount: 0)
    var episodes: [Episode] = []
    for index in 0..<150 {
      episodes.append(
        Episode(
          id: "ep-\(index)",
          title: "Episode \(index)",
          podcastID: "swift",
          podcastTitle: "Swift Talk",
          playbackPosition: index == 0 ? 120 : 0,
          isPlayed: index == 149,
          pubDate: Calendar.current.date(byAdding: .day, value: -index, to: Date()),
          duration: 1800
        )
      )
    }
    podcast = Podcast(
      id: podcast.id,
      title: podcast.title,
      author: podcast.author,
      description: podcast.description,
      artworkURL: podcast.artworkURL,
      feedURL: podcast.feedURL,
      categories: podcast.categories,
      episodes: episodes,
      isSubscribed: podcast.isSubscribed,
      dateAdded: podcast.dateAdded,
      folderId: podcast.folderId,
      tagIds: podcast.tagIds
    )

    let items = CarPlayDataAdapter.makeEpisodeItems(for: podcast)

    XCTAssertEqual(items.count, 100, "Should limit to the 100 most recent episodes")
    XCTAssertEqual(items.first?.episode.id, "ep-0", "Most recent episode should appear first")
    XCTAssertEqual(items.last?.episode.id, "ep-99", "Respect truncation order")
    XCTAssertTrue(items.first?.detailText.contains("30m") ?? false)
    XCTAssertTrue(items.first?.voiceCommands.contains("Play Episode 0") ?? false)
    XCTAssertTrue(items.first?.voiceCommands.contains("from Swift Talk") ?? false)
  }

  func testPlaybackCoordinatorQueueing() {
    #if canImport(Combine)
      let playbackService = StubPlaybackService()
      let coordinator = CarPlayPlaybackCoordinator(playbackService: playbackService)

      let episode1 = Episode(id: "1", title: "First", podcastID: "pod", podcastTitle: "Podcast")
      let episode2 = Episode(id: "2", title: "Second", podcastID: "pod", podcastTitle: "Podcast")

      coordinator.enqueue(episode1)
      coordinator.enqueue(episode2)

      XCTAssertEqual(coordinator.queuedEpisodes.count, 2)

      coordinator.playNow(episode1)

      playbackService.emit(state: .finished(episode1, duration: 10))

      XCTAssertEqual(playbackService.playedEpisodes.map(\.id), ["1", "2"], "Should advance queue after finish")
      XCTAssertEqual(coordinator.queuedEpisodes.count, 0)
    #else
      throw XCTSkip("Combine not available on this platform")
    #endif
  }

  // MARK: - Helpers

  private func makePodcast(id: String, title: String, episodeCount: Int) -> Podcast {
    let episodes = (0..<episodeCount).map { index in
      Episode(
        id: "\(id)-ep-\(index)",
        title: "Episode \(index)",
        podcastID: id,
        podcastTitle: title,
        playbackPosition: 0,
        isPlayed: false,
        pubDate: Calendar.current.date(byAdding: .day, value: -index, to: Date()),
        duration: 1800
      )
    }

    return Podcast(
      id: id,
      title: title,
      author: "Author",
      description: "Description",
      feedURL: URL(string: "https://example.com/feed")!,
      episodes: episodes,
      isSubscribed: true,
      dateAdded: Date()
    )
  }
}

#if canImport(Combine)
  import CombineSupport

  private final class StubPlaybackService: EpisodePlaybackService {
    private let subject = CurrentValueSubject<EpisodePlaybackState, Never>(
      .idle(Episode(id: "stub", title: "Stub"))
    )

    var statePublisher: AnyPublisher<EpisodePlaybackState, Never> {
      subject.eraseToAnyPublisher()
    }

    private(set) var playedEpisodes: [Episode] = []

    func play(episode: Episode, duration maybeDuration: TimeInterval?) {
      playedEpisodes.append(episode)
      subject.send(.playing(episode, position: 0, duration: maybeDuration ?? 0))
    }

    func pause() {
      subject.send(.paused(playedEpisodes.last ?? Episode(id: "stub", title: "Stub"), position: 0, duration: 0))
    }

    func emit(state: EpisodePlaybackState) {
      subject.send(state)
    }
  }
#endif

#endif

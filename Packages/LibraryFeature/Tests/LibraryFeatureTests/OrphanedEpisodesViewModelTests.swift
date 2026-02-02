import XCTest
@testable import LibraryFeature
import CoreModels

@MainActor
final class OrphanedEpisodesViewModelTests: XCTestCase {
  func testQuickPlayDelegatesToCoordinator() async {
    // Arrange
    let playback = MockPlaybackCoordinator()
    let manager = PlaceholderManager()
    let viewModel = OrphanedEpisodesViewModel(
      podcastManager: manager,
      playbackCoordinator: playback
    )
    let episode = Episode(
      id: "ep-1",
      title: "Test",
      podcastID: "pod-1",
      podcastTitle: "Pod",
      duration: 120,
      audioURL: URL(string: "https://example.com/audio.mp3")
    )

    // Act
    await viewModel.quickPlayEpisode(episode)

    // Assert
    XCTAssertEqual(playback.playedEpisodes.first?.id, "ep-1")
  }

  func testQuickPlaySkipsWhenAudioURLMissing() async {
    let playback = MockPlaybackCoordinator()
    let manager = PlaceholderManager()
    let viewModel = OrphanedEpisodesViewModel(
      podcastManager: manager,
      playbackCoordinator: playback
    )

    let episode = Episode(
      id: "ep-no-url",
      title: "Missing URL",
      podcastID: "pod-1",
      podcastTitle: "Pod"
    )

    await viewModel.quickPlayEpisode(episode)

    XCTAssertTrue(playback.playedEpisodes.isEmpty, "Should not attempt playback without audioURL")
  }

  func testDeleteRemovesEpisodeAndReloads() async {
    let ep1 = Episode(
      id: "ep-1",
      title: "First",
      podcastID: "pod-1",
      podcastTitle: "Pod",
      audioURL: URL(string: "https://example.com/one.mp3")
    )
    let ep2 = Episode(
      id: "ep-2",
      title: "Second",
      podcastID: "pod-1",
      podcastTitle: "Pod",
      audioURL: URL(string: "https://example.com/two.mp3")
    )
    let manager = PlaceholderManager(episodes: [ep1, ep2])
    let viewModel = OrphanedEpisodesViewModel(
      podcastManager: manager,
      playbackCoordinator: MockPlaybackCoordinator()
    )

    await viewModel.load()
    XCTAssertEqual(viewModel.episodes.count, 2)

    await viewModel.delete(ep1)

    XCTAssertEqual(manager.lastDeletedId, "ep-1")
    XCTAssertEqual(viewModel.episodes.map(\.id), ["ep-2"])
  }
}

private final class MockPlaybackCoordinator: EpisodePlaybackCoordinating {
  var playedEpisodes: [Episode] = []

  func quickPlayEpisode(_ episode: Episode) async {
    playedEpisodes.append(episode)
  }

  func stopMonitoring() {}
}

private final class PlaceholderManager: PodcastManaging, @unchecked Sendable {
  private(set) var episodes: [Episode]
  private(set) var lastDeletedId: String?

  init(episodes: [Episode] = []) {
    self.episodes = episodes
  }

  func all() -> [Podcast] { [] }
  func find(id: String) -> Podcast? { nil }
  func add(_ podcast: Podcast) {}
  func update(_ podcast: Podcast) {}
  func remove(id: String) {}
  func findByFolder(folderId: String) -> [Podcast] { [] }
  func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] { [] }
  func findByTag(tagId: String) -> [Podcast] { [] }
  func findUnorganized() -> [Podcast] { [] }
  func fetchOrphanedEpisodes() -> [Episode] { episodes }

  func deleteOrphanedEpisode(id: String) -> Bool {
    lastDeletedId = id
    episodes.removeAll { $0.id == id }
    return true
  }

  func deleteAllOrphanedEpisodes() -> Int {
    let count = episodes.count
    episodes.removeAll()
    return count
  }
}

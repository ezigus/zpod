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
      duration: 120
    )

    // Act
    await viewModel.quickPlayEpisode(episode)

    // Assert
    XCTAssertEqual(playback.playedEpisodes.first?.id, "ep-1")
  }
}

private final class MockPlaybackCoordinator: EpisodePlaybackCoordinating {
  var playedEpisodes: [Episode] = []

  func quickPlayEpisode(_ episode: Episode) async {
    playedEpisodes.append(episode)
  }

  func stopMonitoring() {}
}

private final class PlaceholderManager: PodcastManaging {
  func all() -> [Podcast] { [] }
  func find(id: String) -> Podcast? { nil }
  func add(_ podcast: Podcast) {}
  func update(_ podcast: Podcast) {}
  func remove(id: String) {}
  func findByFolder(folderId: String) -> [Podcast] { [] }
  func findByFolderRecursive(folderId: String, folderManager: FolderManaging) -> [Podcast] { [] }
  func findByTag(tagId: String) -> [Podcast] { [] }
  func findUnorganized() -> [Podcast] { [] }
  func fetchOrphanedEpisodes() -> [Episode] { [] }
  func deleteOrphanedEpisode(id: String) -> Bool { false }
  func deleteAllOrphanedEpisodes() -> Int { 0 }
}

import XCTest
@preconcurrency import Combine
@testable import Networking
import CoreModels
import Persistence

final class DownloadIntegrationTests: XCTestCase {
  private var downloadsRoot: URL!
  private var cancellables = Set<AnyCancellable>()

  override func setUp() {
    super.setUp()
    downloadsRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("DownloadIntegration-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)
  }

  override func tearDown() {
    cancellables.removeAll()
    try? FileManager.default.removeItem(at: downloadsRoot)
    downloadsRoot = nil
    super.tearDown()
  }

  @MainActor
  func testCoordinatorDownloadsAndCachesLocalFile() async throws {
    let fileManagerService = try FileManagerService(
      baseDownloadsPath: downloadsRoot,
      configuration: URLSessionConfiguration.ephemeral
    )
    let (_, coordinator) = await MainActor.run { () -> (InMemoryDownloadQueueManager, DownloadCoordinator) in
      let queueManager = InMemoryDownloadQueueManager()
      let coord = DownloadCoordinator(
        queueManager: queueManager,
        fileManagerService: fileManagerService,
        autoProcessingEnabled: true
      )
      return (queueManager, coord)
    }

    let sourceData = Data(repeating: 0x7A, count: 1_024)
    let sourceURL = downloadsRoot.appendingPathComponent("source.mp3")
    try sourceData.write(to: sourceURL)

    let episode = Episode(
      id: "int-ep-1",
      title: "Integration Episode",
      podcastID: "int-pod-1",
      podcastTitle: "Integration Podcast",
      audioURL: sourceURL,
      downloadStatus: .notDownloaded
    )

    let completed = expectation(description: "download completes")
    await MainActor.run {
      coordinator.episodeProgressPublisher
        .sink { update in
          if update.episodeID == episode.id, update.status == .completed {
            completed.fulfill()
          }
        }
        .store(in: &cancellables)
    }

    await MainActor.run { coordinator.addDownload(for: episode, priority: 5) }
    await fulfillment(of: [completed], timeout: 2.0)

    let localURL = await MainActor.run { coordinator.localFileURL(for: episode.id) }
    XCTAssertNotNil(localURL)
    if let localURL {
      XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
      let data = try Data(contentsOf: localURL)
      XCTAssertEqual(data, sourceData)
    }
  }
}

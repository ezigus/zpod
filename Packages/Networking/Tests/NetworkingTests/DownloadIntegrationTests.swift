import XCTest
import Combine
@testable import Networking
import CoreModels
import Persistence

@MainActor
final class DownloadIntegrationTests: XCTestCase {
  private var downloadsRoot: URL!
  private var cancellables = Set<AnyCancellable>()

  override func setUp() async throws {
    try await super.setUp()
    downloadsRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("DownloadIntegration-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)
  }

  override func tearDown() async throws {
    cancellables.removeAll()
    try? FileManager.default.removeItem(at: downloadsRoot)
    downloadsRoot = nil
    try await super.tearDown()
  }

  func testCoordinatorDownloadsAndCachesLocalFile() async throws {
    let fileManagerService = try FileManagerService(
      baseDownloadsPath: downloadsRoot,
      configuration: URLSessionConfiguration.ephemeral
    )
    let queueManager = InMemoryDownloadQueueManager()
    let coordinator = DownloadCoordinator(
      queueManager: queueManager,
      fileManagerService: fileManagerService,
      autoProcessingEnabled: true
    )

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
    coordinator.episodeProgressPublisher
      .sink { update in
        if update.episodeID == episode.id, update.status == .completed {
          completed.fulfill()
        }
      }
      .store(in: &cancellables)

    coordinator.addDownload(for: episode, priority: 5)
    await fulfillment(of: [completed], timeout: 2.0)

    let localURL = coordinator.localFileURL(for: episode.id)
    XCTAssertNotNil(localURL)
    if let localURL {
      XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
      let data = try Data(contentsOf: localURL)
      XCTAssertEqual(data, sourceData)
    }
  }
}

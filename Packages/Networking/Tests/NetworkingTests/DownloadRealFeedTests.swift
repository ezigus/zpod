import XCTest
@preconcurrency import Combine
@testable import Networking
import Persistence
import CoreModels

/// Live RSS feed download verification.
final class DownloadRealFeedTests: XCTestCase {
  private var downloadsRoot: URL!
  private var cancellables = Set<AnyCancellable>()

  override func setUp() {
    super.setUp()
    downloadsRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("RealFeed-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)
  }

  override func tearDown() {
    cancellables.removeAll()
    try? FileManager.default.removeItem(at: downloadsRoot)
    downloadsRoot = nil
    super.tearDown()
  }

  @MainActor
  func testDownloadsFirstEnclosureFromFeeds() async throws {
    let envFeeds = ProcessInfo.processInfo.environment["ZPOD_REAL_FEEDS"]
    let runLiveFeeds = ProcessInfo.processInfo.environment["ZPOD_RUN_LIVE_FEEDS"] == "1"
    if !runLiveFeeds {
      throw XCTSkip("Set ZPOD_RUN_LIVE_FEEDS=1 to exercise live feed downloads")
    }

    let defaultFeeds = [
      "https://feeds.npr.org/510289/podcast.xml",
      "https://feeds.simplecast.com/l2i9YnTd"
    ]

    let feedsString = envFeeds?.trimmingCharacters(in: .whitespacesAndNewlines)
    let chosenFeeds: [String] =
      (feedsString?.isEmpty == false)
      ? feedsString!.split(separator: ",").map(String.init)
      : defaultFeeds

    let feedURLs = chosenFeeds
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .compactMap(URL.init(string:))

    XCTAssertFalse(feedURLs.isEmpty, "No valid feed URLs provided")

    let maxBytesEnv = ProcessInfo.processInfo.environment["ZPOD_MAX_FEED_BYTES"]
    let maxBytes = Int64(maxBytesEnv ?? "") ?? 25 * 1_024 * 1_024

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

    for feedURL in feedURLs {
      let xmlData = try await fetchData(from: feedURL)
      let enclosures = enclosureURLs(in: xmlData)
      guard let enclosureURL = try await pickEnclosure(from: enclosures, maxBytes: maxBytes) else {
        XCTFail("No suitable enclosure found for feed \(feedURL)")
        continue
      }

      let episodeID = UUID().uuidString
      let episode = Episode(
        id: episodeID,
        title: "Live Feed Episode",
        podcastID: feedURL.absoluteString,
        podcastTitle: "Live Feed",
        audioURL: enclosureURL,
        downloadStatus: .notDownloaded
      )

      let completed = expectation(description: "download completes for \(feedURL)")
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
      await fulfillment(of: [completed], timeout: 240.0)

      let localURL = await MainActor.run { coordinator.localFileURL(for: episode.id) }
      XCTAssertNotNil(localURL, "Missing local file for \(feedURL)")
      if let localURL {
        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
        let size = try FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(size, 0, "Downloaded file is empty for \(feedURL)")
      }
    }
  }

  // MARK: - Helpers

  @MainActor private func fetchData(from url: URL) async throws -> Data {
    let (data, response) = try await URLSession.shared.data(from: url)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw NSError(domain: "DownloadRealFeedTests", code: http.statusCode, userInfo: [
        NSLocalizedDescriptionKey: "HTTP \(http.statusCode) for \(url)"
      ])
    }
    return data
  }

  @MainActor private func enclosureURLs(in data: Data) -> [URL] {
    let parser = XMLParser(data: data)
    let delegate = EnclosureParserDelegate()
    parser.delegate = delegate
    parser.parse()
    return delegate.enclosureURLs
  }

  @MainActor private func pickEnclosure(from urls: [URL], maxBytes: Int64) async throws -> URL? {
    for url in urls {
      if let size = try await headContentLength(url: url) {
        if size <= maxBytes { return url }
        continue
      } else {
        // Unknown size: try the first unknown-sized enclosure
        return url
      }
    }
    return nil
  }

  @MainActor private func headContentLength(url: URL) async throws -> Int64? {
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"
    request.timeoutInterval = 30
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      return nil
    }
    if let lengthStr = http.value(forHTTPHeaderField: "Content-Length"), let length = Int64(lengthStr) {
      return length
    }
    // Some servers don't send content-length for HEAD; fall back to body length if present
    return Int64(data.count)
  }
}

private final class EnclosureParserDelegate: NSObject, XMLParserDelegate {
  private(set) var enclosureURLs: [URL] = []

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    if elementName.lowercased() == "enclosure", let urlString = attributeDict["url"],
       let url = URL(string: urlString) {
      enclosureURLs.append(url)
    }
  }
}

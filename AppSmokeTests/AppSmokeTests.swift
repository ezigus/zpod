import XCTest
@testable import zpodLib

final class AppSmokeTests: XCTestCase {
  func testCoreModelsAreAccessibleThroughZpodLib() throws {
    let podcast = Podcast(
      id: "pod-001",
      title: "Test Podcast",
      feedURL: URL(string: "https://example.com/feed.xml")!
    )

    XCTAssertEqual(podcast.id, "pod-001")
    XCTAssertEqual(podcast.title, "Test Podcast")
  }

  func testSharedUtilitiesErrorFormatting() {
    let error = SharedError.networkError("Timeout")
    XCTAssertEqual(error.errorDescription, "Network error: Timeout")
  }
}

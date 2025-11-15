import XCTest
@testable import zpodLib

/// Smoke-level verification that `zpodLib` re-exports the public API surface.
///
/// **Specifications Covered**
/// - `Issues/02.5-testing-cleanup.md` — Smoke coverage for cross-package accessibility.
final class AppSmokeTests: XCTestCase {
  func testCoreModelsAreAccessibleThroughZpodLib() throws {
    // Given: A CoreModels podcast definition exposed via `zpodLib`
    let podcast = Podcast(
      id: "pod-001",
      title: "Test Podcast",
      feedURL: URL(string: "https://example.com/feed.xml")!
    )

    // Then: Accessing CoreModels types through `zpodLib` preserves values
    XCTAssertEqual(podcast.id, "pod-001")
    XCTAssertEqual(podcast.title, "Test Podcast")
  }

  func testSharedUtilitiesErrorFormatting() {
    // Given: A SharedUtilities error surfaced through `zpodLib`
    let error = SharedError.networkError("Timeout")

    // Then: Error descriptions remain available to dependants
    XCTAssertEqual(error.errorDescription, "Network error: Timeout")
  }
}

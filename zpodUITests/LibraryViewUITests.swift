//
//  LibraryViewUITests.swift
//  zpodUITests
//
//  Verifies that LibraryView is wired to the live PodcastManaging repository (Issue #27.1.9).
//
//  Spec scenarios covered:
//  - Given UITEST_SEED_PODCASTS=1, the seeded podcast card appears in Library
//  - The "Heading Library" accessibility heading is present when podcasts exist
//

import XCTest

final class LibraryViewUITests: IsolatedUITestCase {

  // MARK: - Helpers

  /// Taps the Library tab and waits for the tab bar to be available.
  @MainActor
  private func navigateToLibrary() {
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: adaptiveTimeout), "Main tab bar must exist")
    let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
    XCTAssertTrue(
      libraryTab.waitForExistence(timeout: adaptiveShortTimeout),
      "Library tab must be discoverable"
    )
    libraryTab.tap()
  }

  // MARK: - Tests

  /// Given: App launched with UITEST_SEED_PODCASTS=1 (the default for all UI tests)
  /// When:  User taps the Library tab
  /// Then:  The seeded "Swift Talk" podcast card button is visible
  ///
  /// This verifies the full data path:
  ///   PodcastRepository.add() → podcastManager.all() → LibraryView.podcasts → PodcastCardView
  @MainActor
  func testLibraryShowsSeededPodcastCard() throws {
    // UITEST_SEED_PODCASTS=1 is set by default in configuredForUITests()
    app = launchConfiguredApp()
    navigateToLibrary()

    // PodcastCardView is a Button (not NavigationLink) with .buttonStyle(.plain); XCUITest
    // surfaces it under app.buttons. The identifier "Podcast-{podcast.id}" is set in
    // LibraryFeature/ContentView.swift — PodcastCardView.body via
    //   .accessibilityIdentifier("Podcast-\(podcast.id)")
    let podcastCard = app.buttons.matching(identifier: "Podcast-swift-talk").firstMatch
    XCTAssertTrue(
      podcastCard.waitForExistence(timeout: adaptiveTimeout),
      "Seeded 'Swift Talk' podcast card must appear as a button in Library"
    )
  }

  /// Given: App launched with UITEST_SEED_PODCASTS=1
  /// When:  User taps the Library tab
  /// Then:  The "Library" accessibility heading is present
  ///
  /// The heading only renders in the non-empty branch of LibraryView, confirming that
  /// podcastManager.all() returned results and the list path was taken.
  @MainActor
  func testLibraryHeadingIsAccessible() throws {
    app = launchConfiguredApp()
    navigateToLibrary()

    // "Heading Library" is set in LibraryFeature/ContentView.swift — LibraryView.body, the
    // non-empty branch, via: Text("Heading Library").accessibilityIdentifier("Heading Library")
    // XCUITest surfaces it under app.staticTexts.
    let heading = app.staticTexts.matching(identifier: "Heading Library").firstMatch
    XCTAssertTrue(
      heading.waitForExistence(timeout: adaptiveTimeout),
      "Library heading must be present and accessible when podcasts exist"
    )
  }
}

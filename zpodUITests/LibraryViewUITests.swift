//
//  LibraryViewUITests.swift
//  zpodUITests
//
//  Verifies that LibraryView is wired to the live PodcastManaging repository (Issue #27.1.9).
//
//  Spec scenarios covered:
//  - Given UITEST_SEED_PODCASTS=1, the seeded podcast card appears in Library
//  - The "Heading Library" accessibility heading is present when podcasts exist
//  - Given UITEST_SEED_PODCASTS=0 (no subscriptions), Library shows empty state
//

import XCTest
import TestSupport

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
    // PodcastFixtures.swiftTalk.id is used here so the fixture and test stay in sync.
    let podcastCard = app.buttons.matching(identifier: "Podcast-\(PodcastFixtures.swiftTalk.id)").firstMatch
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

  /// Given: App launched with no seeded podcasts (UITEST_SEED_PODCASTS=0)
  /// When:  User taps the Library tab
  /// Then:  The "Library.EmptyState" ContentUnavailableView is visible
  ///
  /// Verifies the empty-state branch of LibraryView (acceptance criterion:
  /// "Given no subscriptions exist, Library tab shows a 'No podcasts yet' empty state").
  /// The empty state is rendered in LibraryFeature/ContentView.swift — LibraryView.body
  /// when podcastManager.all() returns an empty array.
  @MainActor
  func testLibraryShowsEmptyStateWhenNoSubscriptions() throws {
    // Override the global seed flag so the empty state branch is exercised.
    // configuredForUITests(environmentOverrides:) merges this over the base "1" value.
    app = launchConfiguredApp(environmentOverrides: ["UITEST_SEED_PODCASTS": "0"])
    navigateToLibrary()

    // ContentUnavailableView may surface as either an `Other` (with the container identifier)
    // or as its title `StaticText` depending on the SwiftUI version. Use waitForAnyElement
    // to accept either — matching the same dual-check pattern used in OrphanedEpisodesUITests.
    // Container identifier "Library.EmptyState" is set in LibraryFeature/ContentView.swift.
    let emptyContainer = app.otherElements.matching(identifier: "Library.EmptyState").firstMatch
    let emptyTitleText = app.staticTexts
      .matching(NSPredicate(format: "label == %@", "No Podcasts Yet"))
      .firstMatch
    XCTAssertNotNil(
      waitForAnyElement(
        [emptyContainer, emptyTitleText],
        timeout: adaptiveTimeout,
        description: "Library empty state"
      ),
      "Library empty state must appear when no podcasts are subscribed"
    )
  }
}

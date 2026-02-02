import XCTest

final class OrphanedEpisodesUITests: IsolatedUITestCase {

  @MainActor
  func testNavigateAndSeeEmptyState() {
    app = launchConfiguredApp()

    let tabs = TabBarNavigation(app: app)
    let settings = SettingsScreen(app: app)
    XCTAssertTrue(tabs.navigateToSettings(), "Should navigate to Settings tab")
    XCTAssertTrue(settings.navigateToOrphanedEpisodes(), "Should navigate to Orphaned Episodes")

    let emptyState = app.otherElements.matching(identifier: "Orphaned.EmptyState").firstMatch
    let emptyLabel = app.staticTexts.matching(NSPredicate(format: "label == %@", "No Orphaned Episodes"))
      .firstMatch
    XCTAssertNotNil(
      waitForAnyElement(
        [emptyState, emptyLabel],
        timeout: 6,
        description: "Orphaned empty state"
      )
    )
  }

  @MainActor
  func testListShowsOrphansAndAllowsDeleteAll() {
    let seed = seedOrphanedEpisodesPayload([
      OrphanSeed(id: "ep-1", title: "Orphan One", podcastTitle: "Pod A", reason: "Progress"),
      OrphanSeed(id: "ep-2", title: "Orphan Two", podcastTitle: "Pod B", reason: "Downloaded")
    ])

    app = launchConfiguredApp(environmentOverrides: UITestLaunchConfiguration.orphanedEpisodes(seedBase64: seed))
    let tabs = TabBarNavigation(app: app)
    let settings = SettingsScreen(app: app)
    XCTAssertTrue(tabs.navigateToSettings(), "Should navigate to Settings tab")
    XCTAssertTrue(settings.navigateToOrphanedEpisodes())

    let row1 = app.otherElements.matching(identifier: "Orphaned.Row.ep-1").firstMatch
    let row1Title = app.staticTexts.matching(NSPredicate(format: "label == %@", "Orphan One")).firstMatch
    XCTAssertNotNil(
      waitForAnyElement(
        [row1, row1Title],
        timeout: 8,
        description: "Seeded orphan row ep-1"
      )
    )
    let playButton = app.descendants(matching: .any).matching(identifier: "Orphaned.Row.ep-1.Play").firstMatch
    XCTAssertTrue(playButton.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons.matching(identifier: "Orphaned.DeleteAll").firstMatch.exists)

    app.buttons.matching(identifier: "Orphaned.DeleteAll").firstMatch.tap()
    let confirmButton = app.buttons.matching(identifier: "Orphaned.DeleteAllConfirm").firstMatch
    XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
    confirmButton.tap()

    let empty = app.otherElements.matching(identifier: "Orphaned.EmptyState").firstMatch
    let emptyLabel = app.staticTexts.matching(NSPredicate(format: "label == %@", "No Orphaned Episodes"))
      .firstMatch
    XCTAssertNotNil(
      waitForAnyElement([empty, emptyLabel], timeout: 8, description: "Empty state after delete all")
    )
  }

  @MainActor
  func testSwipeToDeleteSingleOrphan() {
    let seed = seedOrphanedEpisodesPayload([
      OrphanSeed(id: "ep-1", title: "Orphan One", podcastTitle: "Pod A", reason: "Progress"),
      OrphanSeed(id: "ep-2", title: "Orphan Two", podcastTitle: "Pod B", reason: "Downloaded")
    ])

    app = launchConfiguredApp(environmentOverrides: UITestLaunchConfiguration.orphanedEpisodes(seedBase64: seed))
    let tabs = TabBarNavigation(app: app)
    let settings = SettingsScreen(app: app)
    XCTAssertTrue(tabs.navigateToSettings(), "Should navigate to Settings tab")
    XCTAssertTrue(settings.navigateToOrphanedEpisodes())

    let row1 = app.otherElements.matching(identifier: "Orphaned.Row.ep-1").firstMatch
    XCTAssertTrue(row1.waitForExistence(timeout: 8))

    let progressBadge = app.descendants(matching: .any).matching(identifier: "Orphaned.Row.ep-1.Reason.Progress").firstMatch
    let progressLabel = app.staticTexts.matching(NSPredicate(format: "label == %@", "Progress")).firstMatch
    XCTAssertNotNil(
      waitForAnyElement(
        [progressBadge, progressLabel],
        timeout: 8,
        description: "Progress badge"
      )
    )
    let downloadedBadge = app.descendants(matching: .any).matching(identifier: "Orphaned.Row.ep-2.Reason.Downloaded").firstMatch
    let downloadedLabel = app.staticTexts.matching(NSPredicate(format: "label == %@", "Downloaded")).firstMatch
    XCTAssertNotNil(
      waitForAnyElement(
        [downloadedBadge, downloadedLabel],
        timeout: 8,
        description: "Downloaded badge"
      )
    )

    row1.swipeLeft()
    let deleteButton = app.buttons.matching(identifier: "Orphaned.Row.ep-1.Delete").firstMatch
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 4))
    deleteButton.tap()

    XCTAssertTrue(waitForElementToDisappear(row1, timeout: 6))
    let row2 = app.otherElements.matching(identifier: "Orphaned.Row.ep-2").firstMatch
    XCTAssertTrue(row2.waitForExistence(timeout: 6))
  }

  @MainActor
  func testSettingsBadgeShowsOrphanCount() {
    let seed = seedOrphanedEpisodesPayload([
      OrphanSeed(id: "ep-1", title: "Badge One", podcastTitle: "BadgePod", reason: "Progress"),
      OrphanSeed(id: "ep-2", title: "Badge Two", podcastTitle: "BadgePod", reason: "Downloaded")
    ])

    app = launchConfiguredApp(environmentOverrides: UITestLaunchConfiguration.orphanedEpisodes(seedBase64: seed))
    let tabs = TabBarNavigation(app: app)
    let settings = SettingsScreen(app: app)
    XCTAssertTrue(tabs.navigateToSettings(), "Should navigate to Settings tab")

    let rowCandidates: [XCUIElement] = [
      app.buttons.matching(identifier: "Settings.Orphaned").firstMatch,
      app.cells.matching(identifier: "Settings.Orphaned").firstMatch,
      app.otherElements.matching(identifier: "Settings.Orphaned").firstMatch,
      app.staticTexts.matching(identifier: "Settings.Orphaned").firstMatch
    ]
    guard let row = waitForAnyElement(rowCandidates, timeout: 8, description: "Orphaned settings row") else {
      XCTFail("Orphaned Episodes row not found")
      return
    }

    let badge = row.descendants(matching: .staticText).matching(NSPredicate(format: "label == %@", "2")).firstMatch
    XCTAssertTrue(badge.waitForExistence(timeout: 6), "Badge count should reflect seeded orphan count")
  }

  // MARK: - Seeding

  private struct OrphanSeed {
    let id: String
    let title: String
    let podcastTitle: String
    let reason: String
  }

  private func seedOrphanedEpisodesPayload(_ seeds: [OrphanSeed]) -> String {
    let payload = seeds.map { seed in
      [
        "id": seed.id,
        "title": seed.title,
        "podcastTitle": seed.podcastTitle,
        "reason": seed.reason
      ]
    }
    let data = try! JSONSerialization.data(withJSONObject: payload, options: [])
    return data.base64EncodedString()
  }
}

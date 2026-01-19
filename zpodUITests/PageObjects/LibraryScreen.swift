//
//  LibraryScreen.swift
//  zpodUITests
//
//  Created for Issue #12.3 - UI Test Infrastructure Cleanup
//
//  Page object describing the Library tab and episode navigation
//

import Foundation
import XCTest

/// Encapsulates Library navigation so tests can reuse the same container discovery logic.
@MainActor
public struct LibraryScreen: BaseScreen {
  public let app: XCUIApplication

  /// Prepare queries that attempt to resolve a container by accessibility identifier.
  private func containerQueries(for identifier: String) -> [XCUIElement] {
    [
      app.scrollViews.matching(identifier: identifier).firstMatch,
      app.tables.matching(identifier: identifier).firstMatch,
      app.collectionViews.matching(identifier: identifier).firstMatch,
      app.otherElements.matching(identifier: identifier).firstMatch,
      app.cells.matching(identifier: identifier).firstMatch,
      app.staticTexts.matching(identifier: identifier).firstMatch,
      app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    ]
  }

  /// Wait for the library shell to be ready.
  public func waitForLibraryContent(timeout: TimeInterval? = nil) -> Bool {
    let candidates = containerQueries(for: "Podcast Cards Container") + [
      app.staticTexts.matching(identifier: "Library Content").firstMatch,
      app.staticTexts.matching(identifier: "Library").firstMatch,
    ]
    return waitForAny(candidates, timeout: timeout) != nil
  }

  /// Taps on a podcast row and waits for the episode list to load.
  public func selectPodcast(_ identifier: String, timeout: TimeInterval? = nil) -> Bool {
    let podcastButton = app.buttons.matching(identifier: identifier).firstMatch
    guard tap(podcastButton, timeout: timeout) else {
      XCTContext.runActivity(named: "Failed to tap podcast '\(identifier)'") { _ in
        XCTFail("Could not tap podcast button with identifier '\(identifier)'")
      }
      return false
    }

    let didShowEpisodeList = waitForEpisodeList(timeout: timeout)
    if !didShowEpisodeList {
      XCTContext.runActivity(named: "Episode list missing for '\(identifier)'") { _ in
        XCTFail("Episode list did not appear after selecting podcast '\(identifier)'")
      }
    }
    return didShowEpisodeList
  }

  /// Waits for the episode list view to render after selecting a podcast.
  public func waitForEpisodeList(timeout: TimeInterval? = nil) -> Bool {
    let listCandidates = containerQueries(for: "Episode List View")
      + containerQueries(for: "Episode Cards Container")
      + [app.staticTexts.matching(identifier: "Episode List").firstMatch]
    return waitForAny(listCandidates, timeout: timeout) != nil
  }

  /// Selects an episode row once the episode list is visible.
  public func selectEpisode(_ identifier: String, timeout: TimeInterval? = nil) -> Bool {
    let episodeButton = app.buttons.matching(identifier: identifier).firstMatch
    return tap(episodeButton, timeout: timeout)
  }
}

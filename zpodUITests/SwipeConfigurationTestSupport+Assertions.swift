//
//  SwipeConfigurationTestSupport+Assertions.swift
//  zpodUITests
//
//  General assertion helpers for swipe configuration tests.
//

import Foundation
import XCTest

extension SwipeConfigurationTestCase {
  @MainActor
  func assertActionList(leadingIdentifiers: [String], trailingIdentifiers: [String]) {
    // Only verify debug baseline if debug overlay is enabled (UITEST_SWIPE_DEBUG=1)
    if baseLaunchEnvironment["UITEST_SWIPE_DEBUG"] == "1" {
      guard waitForBaselineLoaded(timeout: adaptiveShortTimeout) else {
        XCTFail("Swipe configuration baseline never loaded; cannot assert action list.")
        return
      }
    }
    _ = waitForSectionIfNeeded(timeout: postReadinessTimeout)

    if let container = swipeActionsSheetListContainer() {
      for identifier in leadingIdentifiers + trailingIdentifiers {
        _ = ensureVisibleInSheet(identifier: identifier, container: container, scrollAttempts: 4)
      }
      let leading = leadingIdentifiers.map { elementForAction(identifier: $0, within: container) }
      let trailing = trailingIdentifiers.map { elementForAction(identifier: $0, within: container) }
      for element in leading + trailing {
        XCTAssertTrue(
          waitForElement(
            element,
            timeout: postReadinessTimeout,
            description: "Swipe action row \(element.identifier)"
          ),
          "Expected \(element.identifier) to be visible in configuration sheet"
        )
      }
      return
    }

    // Fallback: look for the identifiers globally if the sheet container isn't discoverable yet.
    for identifier in leadingIdentifiers + trailingIdentifiers {
      // Scroll a bit to force materialization in case we're stuck mid-sheet.
      app.swipeDown()
      app.swipeUp()
      let fallbackElement = element(withIdentifier: identifier)
      XCTAssertTrue(
        fallbackElement.waitForExistence(timeout: postReadinessTimeout),
        "Expected \(identifier) to exist in configuration sheet"
      )
    }
    reportAvailableSwipeIdentifiers(context: "assertActionList (fallback identifiers)")
    XCTFail(
      "Swipe configuration sheet container never materialized; captured fallback identifiers for inspection."
    )
  }
}

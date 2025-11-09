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
    _ = waitForElement(
      app.navigationBars["Swipe Actions"],
      timeout: adaptiveShortTimeout,
      description: "Swipe Actions navigation bar"
    )
    _ = waitForBaselineLoaded()

    guard let container = swipeActionsSheetListContainer() else {
      XCTFail("Expected swipe actions list container to exist")
      return
    }

    let leading = leadingIdentifiers.map { elementForAction(identifier: $0, within: container) }
    let trailing = trailingIdentifiers.map { elementForAction(identifier: $0, within: container) }

    for element in leading + trailing {
      XCTAssertTrue(
        waitForElement(
          element,
          timeout: adaptiveShortTimeout,
          description: "Swipe action row \(element.identifier)"
        ),
        "Expected \(element.identifier) to be visible in configuration sheet"
      )
    }
  }
}

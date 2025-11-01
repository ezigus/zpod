//
//  SiriMediaSearchTests.swift
//  SharedUtilitiesTests
//
//  Created by zpod on 2024-01-15.
//

import XCTest

@testable import SharedUtilities

final class SiriMediaSearchTests: XCTestCase {

  // MARK: - Fuzzy Match Tests

  func testExactMatch() {
    let score = SiriMediaSearch.fuzzyMatch(query: "Swift Talk", target: "Swift Talk")
    XCTAssertEqual(score, 1.0, "Exact match should return perfect score")
  }

  func testCaseInsensitiveMatch() {
    let score = SiriMediaSearch.fuzzyMatch(query: "swift talk", target: "Swift Talk")
    XCTAssertEqual(score, 1.0, "Case-insensitive match should return perfect score")
  }

  func testPartialMatch() {
    let score = SiriMediaSearch.fuzzyMatch(query: "Swift", target: "Swift Talk Episode 1")
    XCTAssertGreaterThan(score, 0.7, "Partial match should have high score")
    XCTAssertLessThan(score, 1.0, "Partial match should not be perfect")
  }

  func testPrefixMatch() {
    let score = SiriMediaSearch.fuzzyMatch(query: "Swift Talk", target: "Swift Talk Episode 1")
    XCTAssertGreaterThan(score, 0.7, "Prefix match should have very high score")
  }

  func testTypoTolerance() {
    let score = SiriMediaSearch.fuzzyMatch(query: "Swfit Talk", target: "Swift Talk")
    XCTAssertGreaterThan(score, 0.5, "Single typo should still match reasonably well")
  }

  func testNoMatch() {
    let score = SiriMediaSearch.fuzzyMatch(query: "Python", target: "Swift Talk")
    XCTAssertLessThan(score, 0.5, "Unrelated strings should have low score")
  }

  func testEmptyQuery() {
    let score = SiriMediaSearch.fuzzyMatch(query: "", target: "Swift Talk")
    XCTAssertEqual(score, 0.0, "Empty query should return zero score")
  }

  // MARK: - Temporal Reference Tests

  func testParseLatest() {
    let result = SiriMediaSearch.parseTemporalReference("play the latest episode")
    XCTAssertEqual(result, .latest)
  }

  func testParseNewest() {
    let result = SiriMediaSearch.parseTemporalReference("newest episode of Swift Talk")
    XCTAssertEqual(result, .latest)
  }

  func testParseRecent() {
    let result = SiriMediaSearch.parseTemporalReference("recent Swift Talk")
    XCTAssertEqual(result, .latest)
  }

  func testParseOldest() {
    let result = SiriMediaSearch.parseTemporalReference("oldest episode")
    XCTAssertEqual(result, .oldest)
  }

  func testParseFirst() {
    let result = SiriMediaSearch.parseTemporalReference("first episode of Swift Talk")
    XCTAssertEqual(result, .oldest)
  }

  func testParseNoTemporalReference() {
    let result = SiriMediaSearch.parseTemporalReference("Swift Talk episode 42")
    XCTAssertNil(result)
  }

  func testParseMultipleTemporalReferences() {
    // Should match "latest" first
    let result = SiriMediaSearch.parseTemporalReference("latest newest episode")
    XCTAssertEqual(result, .latest)
  }

  func testParseCaseInsensitive() {
    let result = SiriMediaSearch.parseTemporalReference("LATEST EPISODE")
    XCTAssertEqual(result, .latest)
  }
}

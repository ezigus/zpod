import XCTest
@testable import CoreModels

final class SmartListRuleValidatorTests: XCTestCase {

    // MARK: - Valid Rules

    func testValidPlayStatusRule() {
        let rule = SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed))
        XCTAssertTrue(isValid(rule), "Play status + equals + episodeStatus should be valid")
    }

    func testValidDownloadStatusRule() {
        let rule = SmartListRule(type: .downloadStatus, comparison: .equals, value: .downloadStatus(.downloaded))
        XCTAssertTrue(isValid(rule))
    }

    func testValidStringRule() {
        let rule = SmartListRule(type: .title, comparison: .contains, value: .string("Swift"))
        XCTAssertTrue(isValid(rule))
    }

    func testValidDurationRule() {
        let rule = SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(1800))
        XCTAssertTrue(isValid(rule))
    }

    func testValidRatingRule() {
        let rule = SmartListRule(type: .rating, comparison: .greaterThan, value: .integer(3))
        XCTAssertTrue(isValid(rule))
    }

    func testValidDateRule() {
        let rule = SmartListRule(type: .pubDate, comparison: .within, value: .relativeDate(.last7Days))
        XCTAssertTrue(isValid(rule))
    }

    func testValidBooleanRule() {
        let rule = SmartListRule(type: .isFavorited, comparison: .equals, value: .boolean(true))
        XCTAssertTrue(isValid(rule))
    }

    func testValidPlaybackPositionRule() {
        let rule = SmartListRule(type: .playbackPosition, comparison: .greaterThan, value: .double(0.5))
        XCTAssertTrue(isValid(rule))
    }

    // MARK: - Unsupported Comparison Errors

    func testPlayStatusWithContainsIsInvalid() {
        let rule = SmartListRule(type: .playStatus, comparison: .contains, value: .episodeStatus(.unplayed))
        XCTAssertEqual(validationError(rule), .unsupportedComparison(ruleType: .playStatus, comparison: .contains))
    }

    func testDurationWithBetweenIsInvalid() {
        let rule = SmartListRule(type: .duration, comparison: .between, value: .timeInterval(1800))
        XCTAssertEqual(validationError(rule), .unsupportedComparison(ruleType: .duration, comparison: .between))
    }

    func testStringRuleWithWithinIsInvalid() {
        let rule = SmartListRule(type: .title, comparison: .within, value: .string("test"))
        XCTAssertEqual(validationError(rule), .unsupportedComparison(ruleType: .title, comparison: .within))
    }

    // MARK: - Empty String Errors

    func testEmptyStringValueIsInvalid() {
        let rule = SmartListRule(type: .title, comparison: .contains, value: .string(""))
        XCTAssertEqual(validationError(rule), .emptyStringValue(ruleType: .title))
    }

    func testWhitespaceOnlyStringIsInvalid() {
        let rule = SmartListRule(type: .podcast, comparison: .contains, value: .string("   "))
        XCTAssertEqual(validationError(rule), .emptyStringValue(ruleType: .podcast))
    }

    func testNonEmptyStringIsValid() {
        let rule = SmartListRule(type: .description, comparison: .contains, value: .string("interview"))
        XCTAssertTrue(isValid(rule))
    }

    // MARK: - Numeric Out-of-Range Errors

    func testRatingBelowMinIsInvalid() {
        let rule = SmartListRule(type: .rating, comparison: .equals, value: .integer(0))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .rating, min: 1, max: 5))
    }

    func testRatingAboveMaxIsInvalid() {
        let rule = SmartListRule(type: .rating, comparison: .equals, value: .integer(6))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .rating, min: 1, max: 5))
    }

    func testRatingAtBoundariesIsValid() {
        let min = SmartListRule(type: .rating, comparison: .equals, value: .integer(1))
        let max = SmartListRule(type: .rating, comparison: .equals, value: .integer(5))
        XCTAssertTrue(isValid(min), "Rating 1 should be valid")
        XCTAssertTrue(isValid(max), "Rating 5 should be valid")
    }

    func testPlaybackPositionAboveOneIsInvalid() {
        let rule = SmartListRule(type: .playbackPosition, comparison: .greaterThan, value: .double(1.1))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .playbackPosition, min: 0, max: 1))
    }

    func testPlaybackPositionAtZeroIsValid() {
        let rule = SmartListRule(type: .playbackPosition, comparison: .greaterThan, value: .double(0.0))
        XCTAssertTrue(isValid(rule))
    }

    func testNegativeDurationIsInvalid() {
        let rule = SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(-1))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .duration, min: 0, max: Double.greatestFiniteMagnitude))
    }

    // MARK: - NaN / Infinity Edge Cases

    func testPlaybackPositionNaNIsInvalid() {
        let rule = SmartListRule(type: .playbackPosition, comparison: .greaterThan, value: .double(.nan))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .playbackPosition, min: 0, max: 1))
    }

    func testPlaybackPositionInfinityIsInvalid() {
        let rule = SmartListRule(type: .playbackPosition, comparison: .greaterThan, value: .double(.infinity))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .playbackPosition, min: 0, max: 1))
    }

    func testPlaybackPositionNegativeInfinityIsInvalid() {
        let rule = SmartListRule(type: .playbackPosition, comparison: .greaterThan, value: .double(-.infinity))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .playbackPosition, min: 0, max: 1))
    }

    func testRatingNaNIsInvalid() {
        let rule = SmartListRule(type: .rating, comparison: .equals, value: .double(.nan))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .rating, min: 1, max: 5))
    }

    func testRatingInfinityIsInvalid() {
        let rule = SmartListRule(type: .rating, comparison: .equals, value: .double(.infinity))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .rating, min: 1, max: 5))
    }

    func testDurationNaNIsInvalid() {
        let rule = SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(.nan))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .duration, min: 0, max: Double.greatestFiniteMagnitude))
    }

    func testDurationInfinityIsInvalid() {
        let rule = SmartListRule(type: .duration, comparison: .greaterThan, value: .timeInterval(.infinity))
        XCTAssertEqual(validationError(rule), .numericOutOfRange(ruleType: .duration, min: 0, max: Double.greatestFiniteMagnitude))
    }

    // MARK: - Value Type Mismatch Errors

    func testPlayStatusWithStringValueIsInvalid() {
        let rule = SmartListRule(type: .playStatus, comparison: .equals, value: .string("unplayed"))
        XCTAssertEqual(validationError(rule), .valueTypeMismatch(ruleType: .playStatus))
    }

    func testDurationWithIntegerValueIsInvalid() {
        let rule = SmartListRule(type: .duration, comparison: .greaterThan, value: .integer(30))
        XCTAssertEqual(validationError(rule), .valueTypeMismatch(ruleType: .duration))
    }

    func testDateRuleWithStringValueIsInvalid() {
        let rule = SmartListRule(type: .pubDate, comparison: .within, value: .string("last week"))
        XCTAssertEqual(validationError(rule), .valueTypeMismatch(ruleType: .pubDate))
    }

    // MARK: - validateAll

    func testValidateAllEmptyRulesSucceeds() {
        let result = SmartListRuleValidator.validateAll([])
        XCTAssertTrue(isAllSuccess(result))
    }

    func testValidateAllAllValidSucceeds() {
        let rules = [
            SmartListRule(type: .playStatus, comparison: .equals, value: .episodeStatus(.unplayed)),
            SmartListRule(type: .downloadStatus, comparison: .equals, value: .downloadStatus(.downloaded)),
        ]
        XCTAssertTrue(isAllSuccess(SmartListRuleValidator.validateAll(rules)))
    }

    func testValidateAllCollectsMultipleErrors() {
        let rules = [
            SmartListRule(type: .title, comparison: .contains, value: .string("")),     // empty string
            SmartListRule(type: .rating, comparison: .equals, value: .integer(10)),     // out of range
        ]
        guard case .failure(let validationErrors) = SmartListRuleValidator.validateAll(rules) else {
            XCTFail("Expected failure with multiple errors")
            return
        }
        XCTAssertEqual(validationErrors.errors.count, 2)
        XCTAssertTrue(validationErrors.errors.contains(.emptyStringValue(ruleType: .title)))
        XCTAssertTrue(validationErrors.errors.contains(.numericOutOfRange(ruleType: .rating, min: 1, max: 5)))
    }

    // MARK: - suggestedComparisons

    func testSuggestedComparisonsMatchesAvailableComparisons() {
        for type in SmartListRuleType.allCases {
            XCTAssertEqual(
                SmartListRuleValidator.suggestedComparisons(for: type),
                type.availableComparisons,
                "Suggested comparisons should match availableComparisons for \(type)"
            )
        }
    }

    // MARK: - Error Descriptions

    func testErrorDescriptionsAreNonEmpty() {
        let errors: [SmartListRuleValidator.ValidationError] = [
            .unsupportedComparison(ruleType: .title, comparison: .within),
            .emptyStringValue(ruleType: .title),
            .numericOutOfRange(ruleType: .rating, min: 1, max: 5),
            .valueTypeMismatch(ruleType: .duration),
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - Helpers

    private func isValid(_ rule: SmartListRule) -> Bool {
        if case .success = SmartListRuleValidator.validate(rule) { return true }
        return false
    }

    private func validationError(_ rule: SmartListRule) -> SmartListRuleValidator.ValidationError? {
        if case .failure(let err) = SmartListRuleValidator.validate(rule) { return err }
        return nil
    }

    private func isAllSuccess(_ result: Result<Void, SmartListRuleValidator.ValidationErrors>) -> Bool {
        if case .success = result { return true }
        return false
    }
}

import XCTest
@testable import CoreModels

final class TimeIntervalFormattingTests: XCTestCase {
    func testAbbreviatedDescription_withSecondsDropsZeroMinutes() {
        XCTAssertEqual(TimeInterval(3_600).abbreviatedDescription(includeSeconds: true), "1h")
    }

    func testAbbreviatedDescription_withSecondsIncludesHoursMinutesSeconds() {
        XCTAssertEqual(TimeInterval(3_661).abbreviatedDescription(includeSeconds: true), "1h 1m 1s")
    }

    func testAbbreviatedDescription_withSecondsHandlesSubMinuteDurations() {
        XCTAssertEqual(TimeInterval(59).abbreviatedDescription(includeSeconds: true), "59s")
    }

    func testAbbreviatedDescription_withoutSecondsUsesMinutes() {
        XCTAssertEqual(TimeInterval(3_661).abbreviatedDescription(includeSeconds: false), "1h 1m")
    }

    func testAbbreviatedDescription_withoutSecondsClampsToMinutes() {
        XCTAssertEqual(TimeInterval(45).abbreviatedDescription(includeSeconds: false), "0m")
    }

    func testAbbreviatedDescription_ignoresFractionalSeconds() {
        XCTAssertEqual(TimeInterval(3599.9).abbreviatedDescription(includeSeconds: true), "59m 59s")
    }

    func testAbbreviatedDescription_handlesNegativeOrInfinite() {
        XCTAssertEqual(TimeInterval(-120).abbreviatedDescription(includeSeconds: true), "0s")
        XCTAssertEqual(Double.infinity.abbreviatedDescription(includeSeconds: false), "0m")
    }
}

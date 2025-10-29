//
//  TimeIntervalExtensionsTests.swift
//  SharedUtilitiesTests
//
//  Tests for TimeInterval extension methods
//

import XCTest
@testable import SharedUtilities

final class TimeIntervalExtensionsTests: XCTestCase {
    
    func testAbbreviatedDescriptionWithSeconds() {
        // Given: Various time intervals
        let oneHour: TimeInterval = 3600
        let oneMinute: TimeInterval = 60
        let oneSecond: TimeInterval = 1
        let complex: TimeInterval = 3661 // 1h 1m 1s
        
        // When: Getting abbreviated descriptions with seconds
        let hourDesc = oneHour.abbreviatedDescription(includeSeconds: true)
        let minuteDesc = oneMinute.abbreviatedDescription(includeSeconds: true)
        let secondDesc = oneSecond.abbreviatedDescription(includeSeconds: true)
        let complexDesc = complex.abbreviatedDescription(includeSeconds: true)
        
        // Then: Should format correctly
        XCTAssertEqual(hourDesc, "1h 0m 0s")
        XCTAssertEqual(minuteDesc, "1m 0s")
        XCTAssertEqual(secondDesc, "1s")
        XCTAssertEqual(complexDesc, "1h 1m 1s")
    }
    
    func testAbbreviatedDescriptionWithoutSeconds() {
        // Given: Various time intervals
        let oneHour: TimeInterval = 3600
        let oneMinute: TimeInterval = 60
        let complex: TimeInterval = 3661 // 1h 1m 1s
        
        // When: Getting abbreviated descriptions without seconds
        let hourDesc = oneHour.abbreviatedDescription(includeSeconds: false)
        let minuteDesc = oneMinute.abbreviatedDescription(includeSeconds: false)
        let complexDesc = complex.abbreviatedDescription(includeSeconds: false)
        
        // Then: Should format correctly without seconds
        XCTAssertEqual(hourDesc, "1h 0m")
        XCTAssertEqual(minuteDesc, "1m")
        XCTAssertEqual(complexDesc, "1h 1m")
    }
    
    func testZeroDuration() {
        // Given: Zero time interval
        let zero: TimeInterval = 0
        
        // When: Getting abbreviated description
        let desc = zero.abbreviatedDescription(includeSeconds: true)
        
        // Then: Should return "0s"
        XCTAssertEqual(desc, "0s")
    }
    
    func testLargeValues() {
        // Given: A large time interval (10 hours, 30 minutes, 45 seconds)
        let large: TimeInterval = 37845
        
        // When: Getting abbreviated description
        let withSeconds = large.abbreviatedDescription(includeSeconds: true)
        let withoutSeconds = large.abbreviatedDescription(includeSeconds: false)
        
        // Then: Should format correctly
        XCTAssertEqual(withSeconds, "10h 30m 45s")
        XCTAssertEqual(withoutSeconds, "10h 30m")
    }
}

import XCTest
@testable import CoreModels

/// Unit tests for SmartListRuleEvaluator focusing on rule combinations and comparisons
final class SmartListRuleEvaluatorTests: XCTestCase {
    private var evaluator: SmartListRuleEvaluator!
    private var referenceDate: Date!
    private var sampleEpisode: Episode!

    override func setUp() async throws {
        try await super.setUp()
        evaluator = SmartListRuleEvaluator()
        referenceDate = Date(timeIntervalSince1970: 1_700_200_000)
        sampleEpisode = Episode(
            id: "episode-1",
            title: "Swift Concurrency Deep Dive",
            podcastID: "pod1",
            podcastTitle: "Concurrency Today",
            playbackPosition: 600,
            isPlayed: false,
            pubDate: referenceDate,
            duration: 3_600,
            description: "Learn about actors and structured concurrency",
            downloadStatus: .downloaded,
            isFavorited: true,
            isBookmarked: true,
            isArchived: false,
            rating: 4,
            dateAdded: referenceDate
        )
    }

    override func tearDown() async throws {
        evaluator = nil
        referenceDate = nil
        sampleEpisode = nil
        try await super.tearDown()
    }

    func testEvaluateSmartListRules_AllConditionsMatch() {
        // Given: A rule set requiring favorite, rating, and downloaded status
        let rules = SmartListRuleSet(
            rules: [
                SmartListRule(
                    type: .isFavorited,
                    comparison: .equals,
                    value: .boolean(true)
                ),
                SmartListRule(
                    type: .rating,
                    comparison: .greaterThan,
                    value: .integer(3)
                ),
                SmartListRule(
                    type: .downloadStatus,
                    comparison: .equals,
                    value: .downloadStatus(.downloaded)
                )
            ],
            logic: .and
        )

        // When: Evaluating the episode against the rules
        let matches = evaluator.evaluateSmartListRules(episode: sampleEpisode, rules: rules)

        // Then: All conditions should pass
        XCTAssertTrue(matches)
    }

    func testEvaluateSmartListRules_OrLogicMatchesAnyRule() {
        // Given: A rule set where only one condition matches
        let rules = SmartListRuleSet(
            rules: [
                SmartListRule(
                    type: .title,
                    comparison: .contains,
                    value: .string("Swift")
                ),
                SmartListRule(
                    type: .isArchived,
                    comparison: .equals,
                    value: .boolean(true)
                )
            ],
            logic: .or
        )

        // When: Evaluating the episode against the rule set
        let matches = evaluator.evaluateSmartListRules(episode: sampleEpisode, rules: rules)

        // Then: The episode should still match because the title rule succeeds
        XCTAssertTrue(matches)
    }

    func testEvaluateSmartListRules_NegatedRuleExcludesMatch() {
        // Given: A rule set where a negated condition should exclude the episode
        let rules = SmartListRuleSet(
            rules: [
                SmartListRule(
                    type: .title,
                    comparison: .contains,
                    value: .string("Swift")
                ),
                SmartListRule(
                    type: .playStatus,
                    comparison: .equals,
                    value: .episodeStatus(.played),
                    isNegated: true
                )
            ],
            logic: .and
        )

        // When: Evaluating the episode
        let matches = evaluator.evaluateSmartListRules(episode: sampleEpisode, rules: rules)

        // Then: The negated rule should keep the episode in the results
        XCTAssertTrue(matches)
    }

    func testEvaluateSmartListRules_DateBetweenComparison() {
        // Given: A rule that checks the publication date is between a range
        let start = referenceDate.addingTimeInterval(-3_600)
        let end = referenceDate.addingTimeInterval(3_600)
        let rules = SmartListRuleSet(
            rules: [
                SmartListRule(
                    type: .pubDate,
                    comparison: .between,
                    value: .dateRange(start: start, end: end)
                )
            ],
            logic: .and
        )

        // When: Evaluating the episode
        let matches = evaluator.evaluateSmartListRules(episode: sampleEpisode, rules: rules)

        // Then: The episode should match the date window
        XCTAssertTrue(matches)
    }

    func testEvaluateSmartListRules_NumberComparisonFails() {
        // Given: A rule that expects a longer duration than the episode has
        let rules = SmartListRuleSet(
            rules: [
                SmartListRule(
                    type: .duration,
                    comparison: .greaterThan,
                    value: .timeInterval(5_000)
                )
            ],
            logic: .and
        )

        // When: Evaluating the rule set
        let matches = evaluator.evaluateSmartListRules(episode: sampleEpisode, rules: rules)

        // Then: The episode should not satisfy the rule
        XCTAssertFalse(matches)
    }
}

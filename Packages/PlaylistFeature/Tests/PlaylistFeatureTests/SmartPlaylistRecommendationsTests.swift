import XCTest
import CoreModels
@testable import PlaylistFeature

final class SmartPlaylistRecommendationsTests: XCTestCase {

    private func makeInsights(count: Int) -> [SmartPlaylistInsight] {
        (0..<count).map { i in
            SmartPlaylistInsight(
                text: "Insight \(i)",
                systemImage: "star"
            )
        }
    }

    // MARK: - Empty State

    func testEmptyInsightsArrayHasNoInsights() {
        let view = SmartPlaylistRecommendationsView(insights: [])
        XCTAssertTrue(view.insights.isEmpty)
    }

    // MARK: - Non-empty Insights

    func testInsightCardsCountMatchesInput() {
        let insights = makeInsights(count: 3)
        let view = SmartPlaylistRecommendationsView(insights: insights)
        XCTAssertEqual(view.insights.count, 3)
    }

    func testInsightDisplaysCorrectText() {
        let insight = SmartPlaylistInsight(
            text: "You play this playlist weekly",
            systemImage: "calendar"
        )
        let view = SmartPlaylistRecommendationsView(insights: [insight])

        XCTAssertEqual(view.insights.first?.text, "You play this playlist weekly")
        XCTAssertEqual(view.insights.first?.systemImage, "calendar")
    }

    func testInsightIDIsPreservedThroughView() {
        let fixedID = UUID()
        let insight = SmartPlaylistInsight(id: fixedID, text: "Top playlist", systemImage: "star")
        let view = SmartPlaylistRecommendationsView(insights: [insight])

        XCTAssertEqual(view.insights.first?.id, fixedID)
    }

    func testMultipleInsightsPreserveOrder() {
        let insights = [
            SmartPlaylistInsight(text: "First", systemImage: "1.circle"),
            SmartPlaylistInsight(text: "Second", systemImage: "2.circle"),
            SmartPlaylistInsight(text: "Third", systemImage: "3.circle"),
        ]
        let view = SmartPlaylistRecommendationsView(insights: insights)

        XCTAssertEqual(view.insights.map(\.text), ["First", "Second", "Third"])
    }
}

import CoreModels
import SwiftUI

// MARK: - SmartPlaylistRecommendationsView

/// Displays actionable insight cards generated from play-event patterns.
///
/// Embed this view inside `SmartPlaylistAnalyticsView` as a "Recommendations" section.
/// When there are no insights, an empty-state prompt is shown instead.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct SmartPlaylistRecommendationsView: View {

    let insights: [SmartPlaylistInsight]

    public init(insights: [SmartPlaylistInsight]) {
        self.insights = insights
    }

    public var body: some View {
        if insights.isEmpty {
            Text("Play more episodes to unlock personalised recommendations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("SmartPlaylistRecommendations.EmptyState")
        } else {
            ForEach(insights) { insight in
                InsightCard(insight: insight)
                    .accessibilityIdentifier("SmartPlaylistRecommendations.Insight.\(insight.id)")
            }
        }
    }
}

// MARK: - InsightCard

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
private struct InsightCard: View {
    let insight: SmartPlaylistInsight

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: insight.systemImage)
                .foregroundStyle(.blue)
                .font(.title3)
                .frame(width: 28)

            Text(insight.text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

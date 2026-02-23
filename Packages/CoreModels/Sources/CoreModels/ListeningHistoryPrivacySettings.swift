import Foundation

// MARK: - Listening History Privacy

/// Privacy settings for listening history tracking.
/// Stored separately from the main SettingsRepository to minimize protocol churn.
public protocol ListeningHistoryPrivacyProvider: Sendable {
    /// Whether listening history recording is enabled. Defaults to `true`.
    func isListeningHistoryEnabled() -> Bool
    /// Update the listening history enabled state.
    func setListeningHistoryEnabled(_ enabled: Bool)
}

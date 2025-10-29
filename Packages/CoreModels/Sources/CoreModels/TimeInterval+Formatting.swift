import Foundation

/// Utilities for producing abbreviated, human-readable duration strings that work across platforms.
extension TimeInterval {
    /// Returns a string such as "1h 2m 3s" (when `includeSeconds` is true) or "1h 2m" for positive durations.
    /// - Parameter includeSeconds: When true, seconds are included; otherwise only hours and minutes are shown.
    /// - Returns: An abbreviated duration string appropriate for search facets and smart list displays.
    func abbreviatedDescription(includeSeconds: Bool) -> String {
        guard isFinite else { return includeSeconds ? "0s" : "0m" }

        let clampedDuration = max(0, self)
        let totalSeconds = Int(clampedDuration)

        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        var components: [String] = []

        if hours > 0 {
            components.append("\(hours)h")
        }

        if minutes > 0 || (hours == 0 && !includeSeconds) {
            components.append("\(minutes)m")
        }

        if includeSeconds && (seconds > 0 || components.isEmpty) {
            components.append("\(seconds)s")
        }

        if components.isEmpty {
            return includeSeconds ? "0s" : "0m"
        }

        return components.joined(separator: " ")
    }
}

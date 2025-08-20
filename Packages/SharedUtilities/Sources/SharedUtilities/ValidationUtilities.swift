@preconcurrency import Foundation

public enum ValidationUtilities {
    public static func isValidURL(_ string: String) -> Bool {
        guard !string.isEmpty, let url = URL(string: string) else { return false }
        return url.scheme != nil && url.host != nil
    }

    public static func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        if value < min { return min }
        if value > max { return max }
        return value
    }
}
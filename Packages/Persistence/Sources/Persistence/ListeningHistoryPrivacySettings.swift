import CoreModels
import Foundation

/// UserDefaults-backed implementation of the listening history privacy toggle.
///
/// Thread-safe via `NSLock`. Defaults to enabled (`true`).
public final class UserDefaultsListeningHistoryPrivacySettings: ListeningHistoryPrivacyProvider, @unchecked Sendable {

    private static let key = "listening_history_enabled"
    private let userDefaults: UserDefaults
    private let lock = NSLock()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func isListeningHistoryEnabled() -> Bool {
        lock.withLock {
            // Default to true if never set
            if userDefaults.object(forKey: Self.key) == nil { return true }
            return userDefaults.bool(forKey: Self.key)
        }
    }

    public func setListeningHistoryEnabled(_ enabled: Bool) {
        lock.withLock {
            userDefaults.set(enabled, forKey: Self.key)
        }
    }
}

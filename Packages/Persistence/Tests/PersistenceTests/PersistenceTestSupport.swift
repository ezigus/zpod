import Foundation
import XCTest

struct UserDefaultsTestHarness {
    let suiteName: String
    let userDefaults: UserDefaults
}

extension XCTestCase {
    func makeUserDefaultsHarness(prefix: String) -> UserDefaultsTestHarness {
        let suiteName = "\(prefix).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Failed to create UserDefaults suite \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return UserDefaultsTestHarness(suiteName: suiteName, userDefaults: defaults)
    }
}

import Foundation
import XCTest
import Persistence

struct SettingsRepositoryHarness {
    let suiteName: String
    let repository: UserDefaultsSettingsRepository

    func makeUserDefaults() -> UserDefaults {
        // Create a fresh instance for inspection when needed
        UserDefaults(suiteName: suiteName)!
    }
}

extension XCTestCase {
    func makeSettingsRepository(prefix: String = "settings-domain") -> SettingsRepositoryHarness {
        let suiteName = "\(prefix).\(UUID().uuidString)"
        let repository = UserDefaultsSettingsRepository(suiteName: suiteName)
        addTeardownBlock {
            Task {
                await repository.clearAll()
                UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
            }
        }
        return SettingsRepositoryHarness(suiteName: suiteName, repository: repository)
    }
}

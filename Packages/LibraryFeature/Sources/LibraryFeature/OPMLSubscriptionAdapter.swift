import CoreModels
import FeedParsing
import Foundation

// MARK: - Adapter

/// Adapts a subscribe closure to the FeedParsing.SubscriptionService protocol.
///
/// Accepts a `@Sendable (String) async throws -> Void` closure so that this file does not
/// need to import Networking directly. The closure is constructed in the call site
/// (SettingsHomeView) which can import Networking without naming conflicts.
final class OPMLSubscriptionAdapter: SubscriptionService, @unchecked Sendable {
    private let subscribeHandler: @Sendable (String) async throws -> Void

    init(subscribeHandler: @Sendable @escaping (String) async throws -> Void) {
        self.subscribeHandler = subscribeHandler
    }

    func subscribe(urlString: String) async throws {
        try await subscribeHandler(urlString)
    }
}

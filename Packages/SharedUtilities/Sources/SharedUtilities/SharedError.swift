@preconcurrency import Foundation

public enum SharedError: LocalizedError, Sendable {
    case networkError(String)
    case persistenceError(String)
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .persistenceError(let message):
            return "Persistence error: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        }
    }
}
import Foundation

/// Thread-safe warning accumulator used by parser tests.
final class WarningRecorder: @unchecked Sendable {
    private var storage: [String] = []
    private let lock = NSLock()

    func append(_ warning: String) {
        lock.lock()
        storage.append(warning)
        lock.unlock()
    }

    var values: [String] {
        lock.lock()
        let result = storage
        lock.unlock()
        return result
    }
}

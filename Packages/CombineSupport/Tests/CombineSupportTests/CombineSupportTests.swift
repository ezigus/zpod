import XCTest
import CombineSupport

final class CombineSupportTests: XCTestCase {
    func testModuleReExportsPublisher() {
        // Verify CombineSupport correctly re-exports Combine types.
        let subject = PassthroughSubject<Int, Never>()
        var received: [Int] = []
        let cancellable = subject.sink { received.append($0) }
        subject.send(1)
        XCTAssertEqual(received, [1])
        _ = cancellable
    }
}

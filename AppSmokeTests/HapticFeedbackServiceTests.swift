#if os(iOS)
import XCTest
@testable import SharedUtilities

final class HapticFeedbackServiceTests: XCTestCase {
  @MainActor
  func testHapticsSuppressedWhenVoiceOverRunning() {
    var invokeCount = 0
    var emitCount = 0
    let service = HapticFeedbackService(
      voiceOverStatusProvider: { true },
      onInvoke: { invokeCount += 1 },
      onEmit: { emitCount += 1 }
    )

    service.impact(.light)
    service.selectionChanged()
    service.notifySuccess()
    service.notifyWarning()
    service.notifyError()

    XCTAssertEqual(invokeCount, 5, "All haptic methods should be invoked.")
    XCTAssertEqual(emitCount, 0, "Haptics should be suppressed while VoiceOver is active.")
  }
}
#endif

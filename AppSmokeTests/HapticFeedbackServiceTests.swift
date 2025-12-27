#if os(iOS)
import XCTest
@testable import SharedUtilities

final class HapticFeedbackServiceTests: XCTestCase {
  @MainActor
  func testHapticsSuppressedWhenVoiceOverRunning() {
    let originalProvider = HapticFeedbackService.voiceOverStatusProvider
    let originalOnEmit = HapticFeedbackService.testOnEmit

    defer {
      HapticFeedbackService.voiceOverStatusProvider = originalProvider
      HapticFeedbackService.testOnEmit = originalOnEmit
    }

    var emitCount = 0
    HapticFeedbackService.voiceOverStatusProvider = { true }
    HapticFeedbackService.testOnEmit = { emitCount += 1 }

    let service = HapticFeedbackService.shared
    service.impact(.light)
    service.selectionChanged()
    service.notifySuccess()

    XCTAssertEqual(emitCount, 0, "Haptics should be suppressed while VoiceOver is active.")
  }
}
#endif

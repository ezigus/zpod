import Foundation

#if canImport(UIKit)
  import UIKit
#endif

public enum HapticFeedbackIntensity: Sendable {
  case light
  case medium
  case heavy
  case soft
  case rigid
}

public protocol HapticFeedbackServicing: Sendable {
  @MainActor func impact(_ intensity: HapticFeedbackIntensity)
  @MainActor func selectionChanged()
  @MainActor func notifySuccess()
  @MainActor func notifyWarning()
  @MainActor func notifyError()
}

public final class HapticFeedbackService: HapticFeedbackServicing {
  public static let shared = HapticFeedbackService()

  private init() {}

  @MainActor
  public func impact(_ intensity: HapticFeedbackIntensity) {
    #if canImport(UIKit)
      let generator = UIImpactFeedbackGenerator(style: intensity.uiImpactStyle)
      generator.prepare()
      generator.impactOccurred()
    #endif
  }

  @MainActor
  public func selectionChanged() {
    #if canImport(UIKit)
      let generator = UISelectionFeedbackGenerator()
      generator.prepare()
      generator.selectionChanged()
    #endif
  }

  @MainActor
  public func notifySuccess() {
    #if canImport(UIKit)
      emitNotification(.success)
    #endif
  }

  @MainActor
  public func notifyWarning() {
    #if canImport(UIKit)
      emitNotification(.warning)
    #endif
  }

  @MainActor
  public func notifyError() {
    #if canImport(UIKit)
      emitNotification(.error)
    #endif
  }

  #if canImport(UIKit)
    @MainActor
    private func emitNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
      let generator = UINotificationFeedbackGenerator()
      generator.prepare()
      generator.notificationOccurred(type)
    }
  #endif
}

#if canImport(UIKit)
  extension HapticFeedbackIntensity {
    fileprivate var uiImpactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
      switch self {
      case .light:
        return .light
      case .medium:
        return .medium
      case .heavy:
        return .heavy
      case .soft:
        if #available(iOS 13.0, *) {
          return .soft
        } else {
          return .light
        }
      case .rigid:
        if #available(iOS 13.0, *) {
          return .rigid
        } else {
          return .heavy
        }
      }
    }
  }
#endif

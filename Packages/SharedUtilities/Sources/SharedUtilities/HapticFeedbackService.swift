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

  #if canImport(UIKit)
    private let voiceOverStatusProvider: @MainActor () -> Bool
    private let onInvoke: (@MainActor () -> Void)?
    private let onEmit: (@MainActor () -> Void)?
  #endif

  private init() {
    #if canImport(UIKit)
      voiceOverStatusProvider = { UIAccessibility.isVoiceOverRunning }
      onInvoke = nil
      onEmit = nil
    #endif
  }

  #if canImport(UIKit)
    init(
      voiceOverStatusProvider: @escaping @MainActor () -> Bool,
      onInvoke: (@MainActor () -> Void)? = nil,
      onEmit: (@MainActor () -> Void)? = nil
    ) {
      self.voiceOverStatusProvider = voiceOverStatusProvider
      self.onInvoke = onInvoke
      self.onEmit = onEmit
    }
  #endif

  @MainActor
  public func impact(_ intensity: HapticFeedbackIntensity) {
    #if canImport(UIKit)
      onInvoke?()
      guard isHapticsAllowed else { return }
      let generator = UIImpactFeedbackGenerator(style: intensity.uiImpactStyle)
      generator.prepare()
      generator.impactOccurred()
      onEmit?()
    #endif
  }

  @MainActor
  public func selectionChanged() {
    #if canImport(UIKit)
      onInvoke?()
      guard isHapticsAllowed else { return }
      let generator = UISelectionFeedbackGenerator()
      generator.prepare()
      generator.selectionChanged()
      onEmit?()
    #endif
  }

  @MainActor
  public func notifySuccess() {
    #if canImport(UIKit)
      onInvoke?()
      guard isHapticsAllowed else { return }
      emitNotification(.success)
    #endif
  }

  @MainActor
  public func notifyWarning() {
    #if canImport(UIKit)
      onInvoke?()
      guard isHapticsAllowed else { return }
      emitNotification(.warning)
    #endif
  }

  @MainActor
  public func notifyError() {
    #if canImport(UIKit)
      onInvoke?()
      guard isHapticsAllowed else { return }
      emitNotification(.error)
    #endif
  }

  #if canImport(UIKit)
    @MainActor
    private func emitNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
      let generator = UINotificationFeedbackGenerator()
      generator.prepare()
      generator.notificationOccurred(type)
      onEmit?()
    }

    @MainActor
    private var isHapticsAllowed: Bool {
      !voiceOverStatusProvider()
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

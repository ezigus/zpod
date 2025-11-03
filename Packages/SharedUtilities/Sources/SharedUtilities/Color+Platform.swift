import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Cross-platform shims for system gray palette access.
public extension Color {
  static var platformSystemGray6: Color {
    #if canImport(UIKit)
    return Color(uiColor: .systemGray6)
    #elseif canImport(AppKit)
    if #available(macOS 13.0, *) {
      return Color(nsColor: .controlBackgroundColor)
    } else {
      return Color(nsColor: .windowBackgroundColor)
    }
    #else
    return Color.gray.opacity(0.12)
    #endif
  }

  static var platformSystemGray5: Color {
    #if canImport(UIKit)
    return Color(uiColor: .systemGray5)
    #elseif canImport(AppKit)
    if #available(macOS 13.0, *) {
      return Color(nsColor: .quaternaryLabelColor)
    } else {
      return Color(nsColor: .controlHighlightColor)
    }
    #else
    return Color.gray.opacity(0.2)
    #endif
  }

  static var platformSystemGray4: Color {
    #if canImport(UIKit)
    return Color(uiColor: .systemGray4)
    #elseif canImport(AppKit)
    if #available(macOS 13.0, *) {
      return Color(nsColor: .separatorColor)
    } else {
      return Color(nsColor: .gridColor)
    }
    #else
    return Color.gray.opacity(0.35)
    #endif
  }
}

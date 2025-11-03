#if canImport(SwiftUI)
import SwiftUI

public enum PlatformNavigationBarTitleDisplayMode {
  case automatic
  case inline
  case large
}

#if os(iOS)
private extension PlatformNavigationBarTitleDisplayMode {
  var swiftUIMode: NavigationBarItem.TitleDisplayMode {
    switch self {
    case .automatic:
      return .automatic
    case .inline:
      return .inline
    case .large:
      return .large
    }
  }
}
#endif

public extension View {
  func platformNavigationBarTitleDisplayMode(
    _ mode: PlatformNavigationBarTitleDisplayMode
  ) -> some View {
#if os(iOS)
    navigationBarTitleDisplayMode(mode.swiftUIMode)
#else
    self
#endif
  }

  func platformInsetGroupedListStyle() -> some View {
#if os(iOS)
    listStyle(.insetGrouped)
#elseif os(macOS)
    listStyle(.inset)
#else
    listStyle(.automatic)
#endif
  }
}

public enum PlatformToolbarPlacement {
  @MainActor
  public static var primaryAction: ToolbarItemPlacement {
#if os(iOS)
    .navigationBarTrailing
#else
    .primaryAction
#endif
  }

  @MainActor
  public static var cancellationAction: ToolbarItemPlacement {
#if os(iOS)
    .navigationBarLeading
#else
    .cancellationAction
#endif
  }
}
#endif

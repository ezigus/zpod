#if canImport(UIKit)
import SwiftUI
import UIKit

public extension View {
  func navigationBarAccessibilityIdentifier(_ identifier: String) -> some View {
    background(
      NavigationBarAccessibilityTagger(identifier: identifier)
        .frame(height: 0)
    )
  }
}

private struct NavigationBarAccessibilityTagger: UIViewRepresentable {
  let identifier: String
  private static let initialDelay: TimeInterval = 0.1
  private static let retryInterval: TimeInterval = 0.1
  private static let maxAttempts: Int = 20
  // NOTE: SwiftUI NavigationStack does not expose a navigationController, so we locate the bar via the window hierarchy.

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    scheduleIdentifierUpdate(from: view, attempt: 0)
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    scheduleIdentifierUpdate(from: uiView, attempt: 0)
  }

  private func scheduleIdentifierUpdate(from view: UIView, attempt: Int) {
    let delay = attempt == 0 ? Self.initialDelay : Self.retryInterval
    // Delay gives SwiftUI time to attach the navigation bar to the window hierarchy.
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      guard let navBar = locateNavigationBar(from: view) else {
        guard attempt < Self.maxAttempts else { return }
        scheduleIdentifierUpdate(from: view, attempt: attempt + 1)
        return
      }
      navBar.accessibilityIdentifier = identifier
    }
  }

  @MainActor
  private func locateNavigationBar(from view: UIView) -> UINavigationBar? {
    let window = view.window ?? activeWindows().first(where: { $0.isKeyWindow }) ?? activeWindows().first
    let rootView = window?.rootViewController?.view ?? window
    guard let rootView else { return nil }
    return findNavigationBar(in: rootView)
  }

  @MainActor
  private func activeWindows() -> [UIWindow] {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
      .flatMap { $0.windows }
  }

  private func findNavigationBar(in view: UIView) -> UINavigationBar? {
    if let navBar = view as? UINavigationBar, !navBar.isHidden, navBar.alpha > 0.01 {
      return navBar
    }
    for subview in view.subviews {
      if let navBar = findNavigationBar(in: subview) {
        return navBar
      }
    }
    return nil
  }
}
#else
import SwiftUI

public extension View {
  func navigationBarAccessibilityIdentifier(_ identifier: String) -> some View {
    self
  }
}
#endif

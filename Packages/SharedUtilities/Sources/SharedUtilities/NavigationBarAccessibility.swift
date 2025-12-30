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

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    // Use async delay to ensure SwiftUI has finished rendering the navigation bar
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first?.windows.first,
        let navBar = findNavigationBar(in: window) {
        navBar.accessibilityIdentifier = identifier
      }
    }
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {}

  private func findNavigationBar(in view: UIView) -> UINavigationBar? {
    if let navBar = view as? UINavigationBar {
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

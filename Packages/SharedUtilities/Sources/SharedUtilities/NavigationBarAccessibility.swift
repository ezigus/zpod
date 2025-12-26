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

private struct NavigationBarAccessibilityTagger: UIViewControllerRepresentable {
  let identifier: String

  func makeUIViewController(context: Context) -> NavigationBarAccessibilityController {
    NavigationBarAccessibilityController(identifier: identifier)
  }

  func updateUIViewController(
    _ uiViewController: NavigationBarAccessibilityController,
    context: Context
  ) {
    uiViewController.identifier = identifier
    uiViewController.applyIdentifierIfNeeded()
  }
}

private final class NavigationBarAccessibilityController: UIViewController {
  var identifier: String

  init(identifier: String) {
    self.identifier = identifier
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    applyIdentifierIfNeeded()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    applyIdentifierIfNeeded()
  }

  func applyIdentifierIfNeeded() {
    navigationController?.navigationBar.accessibilityIdentifier = identifier
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

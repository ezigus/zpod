#if canImport(UIKit)
import SharedUtilities
import SwiftUI
import UIKit

/// Presents playback debug controls as a floating overlay available whenever
/// `UITEST_PLAYBACK_DEBUG=1`. Used by UI tests to simulate interruptions.
@MainActor
public final class PlaybackDebugOverlayManager {
  public static let shared = PlaybackDebugOverlayManager()

  private var hostingController: UIHostingController<PlaybackDebugOverlayContainer>?
  private var overlayWindow: UIWindow?
  private weak var activeScene: UIWindowScene?

  nonisolated(unsafe) private var overlayRequestObserver: NSObjectProtocol?
  nonisolated(unsafe) private var sceneActivationObserver: NSObjectProtocol?
  nonisolated(unsafe) private var sceneBackgroundObserver: NSObjectProtocol?
  nonisolated(unsafe) private var appInitObserver: NSObjectProtocol?

  private init() {
    guard Self.isPlaybackDebugEnabled else { return }

    overlayRequestObserver = NotificationCenter.default.addObserver(
      forName: .playbackDebugOverlayRequested,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.showOverlayIfNeeded() }
    }

    sceneActivationObserver = NotificationCenter.default.addObserver(
      forName: UIScene.didActivateNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let scene = notification.object as? UIWindowScene else { return }
      Task { @MainActor in
        self?.activeScene = scene
        self?.showOverlayIfNeeded()
      }
    }

    sceneBackgroundObserver = NotificationCenter.default.addObserver(
      forName: UIScene.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let scene = notification.object as? UIWindowScene else { return }
      Task { @MainActor in
        if scene == self?.activeScene {
          self?.hideOverlay()
        }
      }
    }

    appInitObserver = NotificationCenter.default.addObserver(
      forName: .appDidInitialize,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.showOverlayIfNeeded() }
    }
  }

  deinit {
    [overlayRequestObserver, sceneActivationObserver, sceneBackgroundObserver, appInitObserver]
      .forEach { observer in
        if let observer {
          NotificationCenter.default.removeObserver(observer)
        }
      }
  }

  private static var isPlaybackDebugEnabled: Bool {
    ProcessInfo.processInfo.environment["UITEST_PLAYBACK_DEBUG"] == "1"
  }

  private func showOverlayIfNeeded() {
    guard hostingController == nil else { return }
    guard let scene = activeScene ?? foregroundScene() else { return }
    attachOverlay(to: scene)
  }

  private func foregroundScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
      return active
    }
    return scenes.first(where: { $0.activationState == .foregroundInactive })
  }

  private func attachOverlay(to scene: UIWindowScene) {
    let overlayWindow = PlaybackDebugOverlayWindow(windowScene: scene)
    overlayWindow.windowLevel = .alert + 100
    overlayWindow.frame = scene.coordinateSpace.bounds

    let controller = UIHostingController(rootView: PlaybackDebugOverlayContainer())
    controller.view.backgroundColor = .clear
    controller.view.isAccessibilityElement = false
    controller.view.accessibilityElementsHidden = false

    let rootController = PlaybackDebugOverlayRootViewController(contentController: controller)

    overlayWindow.rootViewController = rootController
    overlayWindow.isHidden = false
    overlayWindow.makeKeyAndVisible()
    overlayWindow.resignKey()

    hostingController = controller
    self.overlayWindow = overlayWindow
  }

  private func hideOverlay() {
    overlayWindow?.isHidden = true
    overlayWindow = nil
    hostingController = nil
  }

  public func hide() {
    hideOverlay()
  }
}

private struct PlaybackDebugOverlayContainer: View {
  var body: some View {
    VStack {
      HStack {
        Spacer(minLength: 0)
        controlStack
      }
      Spacer(minLength: 0)
    }
    .padding([.top, .trailing], 12)
    .ignoresSafeArea()
  }

  private var controlStack: some View {
    VStack(alignment: .trailing, spacing: 8) {
      playSampleButton
      Button("Interruption Began") {
        postInterruption(.began, shouldResume: false)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .tint(.orange)
      .accessibilityIdentifier("Playback.Debug.InterruptionBegan")

      Button("Interruption Ended") {
        postInterruption(.ended, shouldResume: true)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      .tint(.green)
      .accessibilityIdentifier("Playback.Debug.InterruptionEnded")
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(.ultraThinMaterial)
    )
    .shadow(radius: 8)
    .accessibilityIdentifier("Playback Debug Controls")
  }

  private var playSampleButton: some View {
    Button("Play Sample") {
      NotificationCenter.default.post(name: .playerTabPlaySampleRequested, object: nil)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.small)
    .tint(.blue)
    .accessibilityIdentifier("Playback.Debug.PlaySample")
  }

  private func postInterruption(
    _ type: PlaybackDebugInterruptionType,
    shouldResume: Bool
  ) {
    NotificationCenter.default.post(
      name: .playbackDebugInterruption,
      object: nil,
      userInfo: [
        PlaybackDebugNotificationKey.interruptionType: type.rawValue,
        PlaybackDebugNotificationKey.shouldResume: shouldResume
      ]
    )
  }
}

/// UIWindow that only intercepts touches when the debug controls themselves are hit.
private final class PlaybackDebugOverlayWindow: UIWindow {
  override init(windowScene: UIWindowScene) {
    super.init(windowScene: windowScene)
    backgroundColor = .clear
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let hitView = super.hitTest(point, with: event),
          let rootView = rootViewController?.view else {
      return nil
    }

    // Allow interacting with overlay content but pass through taps that only
    // touch the clear hosting view so Player tab interactions still work.
    return hitView === rootView ? nil : hitView
  }
}

/// Hosts the SwiftUI overlay while constraining hit testing to the control bounds.
private final class PlaybackDebugOverlayRootViewController: UIViewController {
  private let contentController: UIViewController

  init(contentController: UIViewController) {
    self.contentController = contentController
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = PlaybackDebugOverlayContainerView()
    view.backgroundColor = .clear
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    addChild(contentController)
    view.addSubview(contentController.view)
    contentController.view.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      contentController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
      contentController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8)
    ])

    contentController.didMove(toParent: self)
  }
}

/// Transparent container that only reports hits when the embedded overlay is touched.
private final class PlaybackDebugOverlayContainerView: UIView {
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    guard let overlayView = subviews.first else { return false }
    let convertedPoint = convert(point, to: overlayView)
    return overlayView.point(inside: convertedPoint, with: event)
  }
}
#endif

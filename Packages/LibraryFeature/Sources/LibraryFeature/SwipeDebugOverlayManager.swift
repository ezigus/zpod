#if os(iOS)
  import CoreModels
  import SettingsDomain
  import SwiftUI
  import UIKit

  // Notification name from zpodApp.swift - the hook is always there
  extension Notification.Name {
    static let appDidInitialize = Notification.Name("ZpodAppDidInitialize")
  }

  /// Manages a persistent debug overlay for UI testing that floats above all other UI.
  /// The overlay provides quick access to preset configurations during test execution.
  @MainActor
  public final class SwipeDebugOverlayManager {
    public static let shared = SwipeDebugOverlayManager()

    private var hostingController: UIHostingController<DebugOverlayView>?
    private var overlayWindow: UIWindow?
    private var currentEntries: [SwipeDebugPresetEntry] = []
    private var currentHandler: ((SwipeActionSettings) -> Void)?
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    private init() {
      // If in debug mode, listen for app initialization notification
      if ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1" {
        observer = NotificationCenter.default.addObserver(
          forName: .appDidInitialize,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          // Handler already runs on main queue, call directly
          // showDefaultPresetsIfNeeded will poll for window availability
          self?.showDefaultPresetsIfNeeded()
        }
      }
    }

    deinit {
      if let observer = observer {
        NotificationCenter.default.removeObserver(observer)
      }
    }

    private func showDefaultPresetsIfNeeded() {
      // Only show if we're in test mode and haven't already shown
      guard ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1",
        overlayWindow == nil
      else {
        return
      }

      // Check if window is available; if not, retry after short delay
      if !isWindowAvailable() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          self?.showDefaultPresetsIfNeeded()
        }
        return
      }

      let presets: [SwipeDebugPresetEntry] = [
        .playback,
        .organization,
        .download,
      ]

      show(entries: presets) { _ in
        // Handler will be set up when configuration view appears
      }
    }

    private func isWindowAvailable() -> Bool {
      return UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })?
        .windows
        .first(where: { $0.isKeyWindow || !$0.isHidden }) != nil
    }

    /// Shows the debug overlay with the given preset entries and handler.
    /// If the overlay is already visible, updates its content.
    /// The overlay persists across all screens until explicitly hidden.
    public func show(
      entries: [SwipeDebugPresetEntry],
      handler: @escaping (SwipeActionSettings) -> Void
    ) {
      currentEntries = entries
      currentHandler = handler

      // If we already have an overlay, just update it
      if let hostingController, let overlayWindow {
        hostingController.rootView = DebugOverlayView(entries: entries, handler: handler)
        overlayWindow.isHidden = false
        return
      }

      // Find the main window (key window or first visible window)
      guard
        let mainWindow = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first(where: { $0.activationState == .foregroundActive })?
          .windows
          .first(where: { $0.isKeyWindow || !$0.isHidden })
      else {
        return
      }

      // Create hosting controller with overlay view
      let hostingController = UIHostingController(
        rootView: DebugOverlayView(entries: entries, handler: handler)
      )
      hostingController.view.backgroundColor = .clear
      hostingController.view.isAccessibilityElement = false
      hostingController.view.accessibilityElementsHidden = false

      // Add overlay view directly to the main window's root view controller
      // This ensures it's in the same window hierarchy that XCUITest can see
      if let rootVC = mainWindow.rootViewController {
        rootVC.addChild(hostingController)
        mainWindow.addSubview(hostingController.view)

        // Position overlay above everything in the main window
        hostingController.view.frame = mainWindow.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: rootVC)
      }

      self.hostingController = hostingController
      self.overlayWindow = mainWindow  // Store reference to main window, not a new window
    }

    /// Hides the debug overlay and releases resources
    func hide() {
      hostingController?.view.removeFromSuperview()
      hostingController?.removeFromParent()
      hostingController = nil
      overlayWindow = nil
      currentEntries = []
      currentHandler = nil
    }
  }

  private struct DebugOverlayView: View {
    let entries: [SwipeDebugPresetEntry]
    let handler: (SwipeActionSettings) -> Void

    var body: some View {
      VStack(alignment: .trailing, spacing: 8) {
        ForEach(entries, id: \.identifier) { entry in
          Button(entry.shortTitle) {
            handler(entry.preset)
          }
          .buttonStyle(.borderedProminent)
          .tint(.accentColor)
          .accessibilityIdentifier(entry.identifier + ".Overlay")
          .accessibilityLabel(entry.shortTitle)
        }
        Button("Reset") {
          handler(.default)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("SwipeActions.Debug.ApplyPreset.Default.Overlay")
        .accessibilityLabel("Reset to Default")
      }
      .padding(12)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
      .allowsHitTesting(true)
      .accessibilityElement(children: .contain)
    }
  }
#endif

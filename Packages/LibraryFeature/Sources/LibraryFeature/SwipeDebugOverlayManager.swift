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
      // In test mode, listen for the app initialization hook
      if ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1" {
        observer = NotificationCenter.default.addObserver(
          forName: .appDidInitialize,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          Task { @MainActor in
            self?.showDefaultPresetsIfNeeded()
          }
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

      let presets: [SwipeDebugPresetEntry] = [
        .playback,
        .organization,
        .download,
      ]

      show(entries: presets) { _ in
        // Handler will be set up when configuration view appears
      }
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

      // Find the active window scene
      guard
        let scene = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first(where: { $0.activationState == .foregroundActive })
      else {
        return
      }

      // Create a dedicated overlay window that floats above everything
      let window = UIWindow(windowScene: scene)
      window.windowLevel = .alert + 100  // Very high level to ensure visibility
      window.backgroundColor = .clear
      window.frame = scene.screen.bounds

      let hostingController = UIHostingController(
        rootView: DebugOverlayView(entries: entries, handler: handler)
      )
      hostingController.view.backgroundColor = .clear
      hostingController.view.frame = window.bounds

      window.rootViewController = hostingController

      // Make window visible but don't steal key status from the main window
      window.makeKeyAndVisible()

      // Immediately resign key status so the main window stays interactive
      if let mainWindow = scene.windows.first(where: { $0.isKeyWindow == false }) {
        mainWindow.makeKey()
      }

      self.hostingController = hostingController
      self.overlayWindow = window
    }

    /// Hides the debug overlay and releases resources
    func hide() {
      overlayWindow?.isHidden = true
      overlayWindow = nil
      hostingController = nil
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

//
//  ZpodApp.swift
//  zpod
//
//  Created by Eric Ziegler on 7/12/25.
//

import SharedUtilities
import SwiftUI
import UIKit

#if canImport(LibraryFeature)
  import SwiftData
  import LibraryFeature
#endif

// Notification posted when app initializes - debug tools can listen for this
extension Notification.Name {
  static let appDidInitialize = Notification.Name("ZpodAppDidInitialize")
}

@main
struct ZpodApp: App {

  init() {
    disableHardwareKeyboard()
    configureSiriSnapshots()
    configureCarPlayDependencies()

    // Force creation of debug overlay manager BEFORE notification is posted
    // This ensures the observer is registered when notification fires
    // Note: UI tests run with UITEST_SWIPE_DEBUG=1 regardless of DEBUG build setting
    #if canImport(LibraryFeature)
      if ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1" {
        _ = SwipeDebugOverlayManager.shared  // Creates observer immediately (sync)
      }
    #endif

    // Always post initialization notification - debug tools can listen if needed
    // This is harmless when nothing is listening (zero cost, loose coupling)
    NotificationCenter.default.post(name: .appDidInitialize, object: nil)
  }

  #if canImport(LibraryFeature)
    // Create model container as a static property to ensure single instance
    private static let sharedModelContainer: ModelContainer = {
      // Detect UI testing environment early
      let isUITesting =
        ProcessInfo.processInfo.environment["UITEST_DISABLE_DOWNLOAD_COORDINATOR"] == "1"

      if isUITesting {
        print("🧪 UI Test mode - creating in-memory ModelContainer")
        do {
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
          let container = try ModelContainer(for: LibraryFeature.Item.self, configurations: config)
          print("✅ UI Test: Successfully created in-memory ModelContainer")
          return container
        } catch {
          print("❌ UI Test: Failed to create ModelContainer: \(error)")
          fatalError("Failed to create in-memory ModelContainer for UI tests: \(error)")
        }
      } else {
        print("📱 Production mode - creating persistent ModelContainer")
        do {
          let schema = Schema([LibraryFeature.Item.self])
          let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
          let container = try ModelContainer(for: schema, configurations: [config])
          print("✅ Production: Successfully created persistent ModelContainer")
          return container
        } catch {
          print("❌ Production: Failed to create ModelContainer: \(error)")
          fatalError("Could not create ModelContainer for production: \(error)")
        }
      }
    }()
  #endif

  #if canImport(LibraryFeature)
    private static let sharedPodcastManager: InMemoryPodcastManager = InMemoryPodcastManager()
  #endif

  var body: some Scene {
    WindowGroup {
      #if canImport(LibraryFeature)
        ContentView(podcastManager: Self.sharedPodcastManager)
          .onContinueUserActivity("us.zig.zpod.playEpisode") { userActivity in
            handlePlayEpisodeActivity(userActivity)
          }
      #else
        ContentView()
      #endif
    }
    #if canImport(LibraryFeature)
      .modelContainer(Self.sharedModelContainer)
    #endif
  }

  private func configureCarPlayDependencies() {
    #if canImport(CarPlay)
      CarPlayDependencyRegistry.configure(podcastManager: Self.sharedPodcastManager)
    #endif
  }

  private func configureSiriSnapshots() {
    guard #available(iOS 14.0, *) else { return }
    SiriSnapshotCoordinator(podcastManager: Self.sharedPodcastManager).refreshAll()
  }

  private func disableHardwareKeyboard() {
    // Only disable hardware keyboard for UI tests, not integration tests
    let isUITesting =
      ProcessInfo.processInfo.environment["UITEST_DISABLE_DOWNLOAD_COORDINATOR"] == "1"

    #if targetEnvironment(simulator)
      guard isUITesting else {
        // Don't interfere with integration tests - only apply to UI tests
        return
      }

      // To ensure the software keyboard appears in the simulator during UI tests,
      // please manually disable the hardware keyboard in the Simulator via:
      //  Hardware > Keyboard > "Connect Hardware Keyboard" (uncheck)
      print(
        "ℹ️ Please disable the hardware keyboard in the Simulator: Hardware > Keyboard > 'Connect Hardware Keyboard'"
      )
    #endif
  }

  private func configureAnimationsForUITesting() {
    // Disable animations when running UI tests to prevent hanging on "waiting for app to idle"
    let disableAnimations = ProcessInfo.processInfo.environment["UITEST_DISABLE_ANIMATIONS"] == "1"

    guard disableAnimations else { return }

    print("🧪 UI Test mode - disabling animations to prevent test hanging")

    // Disable UIView animations globally
    UIView.setAnimationsEnabled(false)

    // Set Core Animation layer speed to complete animations instantly
    // Setting speed to 0 can cause some issues, so we use a very high value instead
    DispatchQueue.main.async {
      for scene in UIApplication.shared.connectedScenes {
        if let windowScene = scene as? UIWindowScene {
          for window in windowScene.windows {
            window.layer.speed = 1000.0  // Complete animations instantly
          }
        }
      }
    }

    // Apply again after a short delay to catch any windows created later
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      for scene in UIApplication.shared.connectedScenes {
        if let windowScene = scene as? UIWindowScene {
          for window in windowScene.windows {
            window.layer.speed = 1000.0
          }
        }
      }
    }
  }

  #if canImport(LibraryFeature)
    /// Handles NSUserActivity from Siri to play a specific episode
    private func handlePlayEpisodeActivity(_ userActivity: NSUserActivity) {
      guard let episodeId = userActivity.userInfo?["episodeId"] as? String else {
        print("⚠️ handlePlayEpisodeActivity: No episodeId in userInfo")
        return
      }

      print("🎧 Siri requested playback for episode: \(episodeId)")

      // Trigger playback via CarPlay dependencies
      Task { @MainActor in
        // Find the episode across all podcasts
        guard let episode = findEpisode(byId: episodeId) else {
          print("⚠️ Episode not found: \(episodeId)")
          return
        }

        print("📱 Starting playback for episode: \(episode.title)")

        // Get the queue manager from CarPlay dependencies
        let dependencies = CarPlayDependencyRegistry.resolve()
        dependencies.queueManager.playNow(episode)

        print("✅ Episode playback initiated via Siri")
      }
    }

    /// Searches for an episode by ID across all subscribed podcasts
    private func findEpisode(byId episodeId: String) -> Episode? {
      let podcasts = Self.sharedPodcastManager.all()
      for podcast in podcasts {
        if let episode = podcast.episodes.first(where: { $0.id == episodeId }) {
          return episode  // Early exit when found
        }
      }
      return nil
    }
  #endif

  /// Configures the swipe debug overlay for UI testing
  /// Shows a persistent floating overlay with preset buttons when UITEST_SWIPE_DEBUG=1
  private func configureSwipeDebugOverlay() {
    guard ProcessInfo.processInfo.environment["UITEST_SWIPE_DEBUG"] == "1" else {
      return
    }

    // Called from onChange(of: scenePhase), so scene is already active
    // Use a small delay to ensure window hierarchy is fully initialized
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(0.5))

      let presets: [SwipeDebugPresetEntry] = [
        .playback,
        .organization,
        .download,
      ]

      SwipeDebugOverlayManager.shared.show(entries: presets) { settings in
        // Handler will be set up properly when the configuration view appears
      }
    }
  }
}

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

@main
struct ZpodApp: App {

  init() {
    disableHardwareKeyboard()
    configureAnimationsForUITesting()
    configureSiriSnapshots()
    configureCarPlayDependencies()
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
      #else
        ContentView()
      #endif
    }
    #if canImport(LibraryFeature)
      .modelContainer(Self.sharedModelContainer)
      .onContinueUserActivity("us.zig.zpod.playEpisode") { userActivity in
        handlePlayEpisodeActivity(userActivity)
      }
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

      // Trigger playback via the shared podcast manager
      // Note: This assumes the PodcastManager has a method to start playback
      // If not already implemented, this will need to be added
      Task { @MainActor in
        // TODO: Implement actual playback triggering
        // For now, just log that we received the request
        print("📱 Would start playback for episode: \(episodeId)")
      }
    }
  #endif
}

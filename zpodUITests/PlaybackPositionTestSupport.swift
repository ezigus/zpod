import OSLog
import XCTest

/// Shared test support for playback position tests.
/// Used by both PlaybackPositionTickerTests and PlaybackPositionAVPlayerTests.
///
/// **Issue**: 03.3.2.1 - Extract Shared Test Infrastructure
///
/// This protocol extracts the navigation, assertion, and utility methods from
/// PlaybackPositionUITests so both Ticker and AVPlayer test classes can share them.
@MainActor
protocol PlaybackPositionTestSupport: SmartUITesting {
  var app: XCUIApplication! { get set }
  static var logger: Logger { get }
}

extension PlaybackPositionTestSupport where Self: XCTestCase {

  // MARK: - Test Audio Helpers
  
  /// Returns the file URL for a bundled test audio file from the test bundle.
  ///
  /// **Important**: Uses Bundle(for: type(of: self)) to access the TEST bundle,
  /// not Bundle.main (which is the app bundle and won't contain test resources).
  ///
  /// - Parameters:
  ///   - name: Audio file name without extension (e.g., "test-episode-short")
  ///   - ext: File extension (default: "m4a", can use "aiff")
  /// - Returns: file:// URL to the audio file, or nil if not found
  nonisolated func testAudioURL(named name: String, extension ext: String = "m4a") -> URL? {
    Bundle(for: type(of: self)).url(
      forResource: name,
      withExtension: ext
    )
  }
  
  /// Copies test audio files to /tmp directory and returns environment variables.
  ///
  /// **Why /tmp?** The app runs in a separate sandbox and cannot read files
  /// from the test bundle. On simulator, /tmp is accessible to both processes.
  ///
  /// Call this before launching the app to inject test audio file paths that AVPlayer can access.
  /// The app reads these environment variables to populate Episode.audioURL.
  ///
  /// **Environment Variables Set**:
  /// - UITEST_AUDIO_SHORT_PATH: ~6.5s test audio (in /tmp)
  /// - UITEST_AUDIO_MEDIUM_PATH: 15s test audio (in /tmp)
  /// - UITEST_AUDIO_LONG_PATH: 20s test audio (in /tmp)
  ///
  /// **Cleanup**: Call `cleanupAudioLaunchEnvironment()` in tearDown when needed.
  ///
  /// - Returns: Dictionary of environment variables to merge into launchEnvironment
  func audioLaunchEnvironment() -> [String: String] {
    let fileManager = FileManager.default
    var env: [String: String] = [:]
    var failures: [String] = []
    
    // Use /tmp directory (accessible on simulator to both test runner and app)
    let audioDir = URL(fileURLWithPath: "/tmp/zpod-uitest-audio")
    
    // Create directory if needed
    do {
      try fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
    } catch {
      XCTFail("Failed to create audio directory at \(audioDir.path): \(error.localizedDescription)")
      return env
    }
    
    // Copy each audio file from test bundle to /tmp
    let audioFiles: [(name: String, envKey: String)] = [
      ("test-episode-short", "UITEST_AUDIO_SHORT_PATH"),
      ("test-episode-medium", "UITEST_AUDIO_MEDIUM_PATH"),
      ("test-episode-long", "UITEST_AUDIO_LONG_PATH")
    ]
    
    for (name, envKey) in audioFiles {
      guard let sourceURL = testAudioURL(named: name) else {
        failures.append("\(name).m4a missing from test bundle")
        XCTFail("Missing audio file in test bundle: \(name).m4a")
        continue
      }
      
      let destURL = audioDir.appendingPathComponent("\(name).m4a")
      
      // Always recopy to ensure fresh files (remove existing first)
      try? fileManager.removeItem(at: destURL)
      
      do {
        try fileManager.copyItem(at: sourceURL, to: destURL)
        Self.logger.debug("Copied test audio: \(name, privacy: .public).m4a -> \(destURL.path, privacy: .public)")
      } catch {
        failures.append("\(name).m4a copy failed: \(error.localizedDescription)")
        XCTFail("Failed to copy \(name).m4a to temp directory: \(error.localizedDescription)")
        continue
      }
      
      env[envKey] = destURL.path
    }

    if !failures.isEmpty {
      XCTFail("Audio environment incomplete: \(failures.joined(separator: "; "))")
    }
    Self.logger.debug("Audio environment configured: \(env.keys.joined(separator: ", "), privacy: .public)")
    return env
  }

  nonisolated func cleanupAudioLaunchEnvironment() {
    let audioDir = URL(fileURLWithPath: "/tmp/zpod-uitest-audio")
    guard FileManager.default.fileExists(atPath: audioDir.path) else { return }
    do {
      try FileManager.default.removeItem(at: audioDir)
    } catch {
      let logger = Logger(subsystem: "us.zig.zpod", category: "PlaybackPositionTestSupport")
      logger.debug("Test audio cleanup failed: \(error.localizedDescription, privacy: .public)")
    }
  }
  
  /// Validates that all required test audio files exist in the test bundle.
  ///
  /// Call this in test setup (setUpWithError) to fail fast if audio is missing.
  /// Prevents confusing timeout failures when audio files aren't properly added.
  nonisolated func validateTestAudioExists() {
    let files = [
      ("test-episode-short", "m4a"),
      ("test-episode-medium", "m4a"),
      ("test-episode-long", "m4a")
    ]
    
    for (name, ext) in files {
      guard testAudioURL(named: name, extension: ext) != nil else {
        XCTFail("""
          ❌ Missing required test audio file: \(name).\(ext)
          
          Expected location: TestResources/Audio/ in zpodUITests bundle
          
          Fix: Ensure files are added to Xcode project with:
          - Folder references (blue folder icon, not yellow)
          - Target membership: zpodUITests only
          """)
        return
      }
    }
  }

  // MARK: - Navigation Helpers

  /// Navigate to Library tab and start playback of test episode.
  /// Returns true if playback started successfully.
  func startPlayback() -> Bool {
    logBreadcrumb("startPlayback: select Library tab")
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    let libraryTab = tabBar.buttons.matching(identifier: "Library").firstMatch
    guard libraryTab.waitForExistence(timeout: adaptiveTimeout) else {
      XCTFail("Library tab not found")
      return false
    }
    libraryTab.tap()

    // Wait for library content
    logBreadcrumb("startPlayback: waiting for library content")
    guard waitForContentToLoad(
      containerIdentifier: "Podcast Cards Container",
      timeout: adaptiveTimeout
    ) else {
      XCTFail("Library content failed to load")
      return false
    }

    // Navigate to podcast
    logBreadcrumb("startPlayback: open podcast")
    let podcastButton = app.buttons.matching(identifier: "Podcast-swift-talk").firstMatch
    guard podcastButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Podcast button not found")
      return false
    }
    podcastButton.tap()

    // Wait for episode list
    logBreadcrumb("startPlayback: waiting for episode list")
    guard waitForContentToLoad(
      containerIdentifier: "Episode List View",
      itemIdentifiers: ["Episode-st-001"],
      timeout: adaptiveTimeout
    ) else {
      XCTFail("Episode list failed to load")
      return false
    }

    // Start playback
    logBreadcrumb("startPlayback: tap quick play")
    tapQuickPlayButton(in: app, timeout: adaptiveShortTimeout)

    // Verify mini-player appeared
    logBreadcrumb("startPlayback: waiting for mini player")
    let miniPlayer = miniPlayerElement(in: app)
    guard miniPlayer.waitForExistence(timeout: adaptiveTimeout) else {
      XCTFail("Mini player did not appear after playback started")
      return false
    }

    return true
  }

  /// Navigate to Player tab and start playback using the sample episode controls.
  /// Returns true if playback started successfully.
  func startPlaybackFromPlayerTab() -> Bool {
    logBreadcrumb("startPlaybackFromPlayerTab: select Player tab")
    let tabBar = app.tabBars.matching(identifier: "Main Tab Bar").firstMatch
    let playerTab = tabBar.buttons.matching(identifier: "Player").firstMatch
    guard playerTab.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Player tab not found")
      return false
    }
    playerTab.tap()

    logBreadcrumb("startPlaybackFromPlayerTab: waiting for episode detail")
    guard waitForContentToLoad(
      containerIdentifier: "Episode Detail View",
      timeout: adaptiveTimeout
    ) else {
      XCTFail("Episode detail failed to load")
      return false
    }

    logBreadcrumb("startPlaybackFromPlayerTab: tap play")
    let episodeDetail = app.otherElements.matching(identifier: "Episode Detail View").firstMatch
    let playButton = episodeDetail.buttons.matching(identifier: "Play").firstMatch
    guard playButton.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Play button not found in episode detail")
      return false
    }
    playButton.tap()

    logBreadcrumb("startPlaybackFromPlayerTab: waiting for mini player")
    let miniPlayer = miniPlayerElement(in: app)
    guard miniPlayer.waitForExistence(timeout: adaptiveTimeout) else {
      XCTFail("Mini player did not appear after playback started")
      return false
    }

    return true
  }

  /// Expand mini-player to full player view.
  /// Returns true if expansion succeeded.
  func expandPlayer() -> Bool {
    logBreadcrumb("expandPlayer: tap mini player")
    let miniPlayer = miniPlayerElement(in: app)
    guard miniPlayer.waitForExistence(timeout: adaptiveShortTimeout) else {
      XCTFail("Mini player not visible")
      return false
    }

    miniPlayer.tap()

    let expandedPlayer = app.otherElements.matching(identifier: "Expanded Player").firstMatch
    logBreadcrumb("expandPlayer: waiting for expanded player")
    guard expandedPlayer.waitForExistence(timeout: adaptiveTimeout) else {
      XCTFail("Expanded player did not appear")
      return false
    }

    return true
  }

  // MARK: - Slider Value Helpers

  func progressSlider() -> XCUIElement? {
    let expandedPlayer = app.otherElements.matching(identifier: "Expanded Player").firstMatch
    guard expandedPlayer.waitForExistence(timeout: adaptiveShortTimeout) else {
      return nil
    }
    return expandedPlayer.sliders.matching(identifier: "Progress Slider").firstMatch
  }

  /// Get the progress slider's current value string.
  func getSliderValue() -> String? {
    guard let slider = progressSlider() else {
      return nil
    }
    guard slider.waitForExistence(timeout: adaptiveShortTimeout) else {
      return nil
    }
    return slider.value as? String
  }

  /// Extract numeric position from slider value string (format: "X:XX of Y:YY").
  func extractCurrentPosition(from value: String?) -> TimeInterval? {
    guard let value = value else { return nil }

    // Value format: "0:30 of 60:00" or similar
    let components = value.components(separatedBy: " of ")
    guard let timeString = components.first else { return nil }

    return parseTimeString(timeString)
  }
  
  /// Extract total duration from slider value string (format: "X:XX of Y:YY").
  func extractTotalDuration(from value: String?) -> TimeInterval? {
    guard let value = value else { return nil }

    // Value format: "0:30 of 60:00" or similar
    let components = value.components(separatedBy: " of ")
    guard components.count == 2, let timeString = components.last else { return nil }

    return parseTimeString(timeString.trimmingCharacters(in: .whitespaces))
  }

  func recordAudioDebugOverlay(_ context: String) {
    let overlay = app.otherElements.matching(identifier: "Audio Debug Overlay").firstMatch
    let text = overlay.exists ? overlay.label : "Audio Debug Overlay not found"
    let attachment = XCTAttachment(string: text)
    let name = "Audio Debug Overlay (\(context))"
    attachment.name = name
    attachment.lifetime = .keepAlways
    XCTContext.runActivity(named: name) { activity in
      activity.add(attachment)
    }
  }

  /// Parse time string "MM:SS" or "H:MM:SS" to seconds.
  private func parseTimeString(_ timeString: String) -> TimeInterval? {
    let components = timeString.components(separatedBy: ":")

    if components.count == 2 {
      // MM:SS format
      guard let minutes = Int(components[0]),
            let seconds = Int(components[1]) else { return nil }
      return TimeInterval(minutes * 60 + seconds)
    } else if components.count == 3 {
      // H:MM:SS format
      guard let hours = Int(components[0]),
            let minutes = Int(components[1]),
            let seconds = Int(components[2]) else { return nil }
      return TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    return nil
  }

  // MARK: - Position Advancement Helpers

  /// Wait for the slider position to advance beyond the initial value.
  /// Uses predicate-based waiting instead of Thread.sleep for reliability.
  ///
  /// - Parameters:
  ///   - initialValue: The starting slider value string
  ///   - timeout: Maximum time to wait (default 5.0s for ticker, use 10.0s for AVPlayer)
  /// - Returns: The new slider value if position advanced, nil if timeout
  func waitForPositionAdvancement(
    beyond initialValue: String?,
    timeout: TimeInterval = 5.0
  ) -> String? {
    guard let slider = progressSlider() else {
      return nil
    }
    guard slider.waitForExistence(timeout: adaptiveShortTimeout) else {
      return nil
    }

    let initialPosition = extractCurrentPosition(from: initialValue) ?? 0

    var observedValue: String?
    let advanced = waitForState(
      timeout: timeout,
      pollInterval: 0.1,
      description: "position advancement"
    ) {
      guard let currentValue = slider.value as? String,
            let currentPosition = self.extractCurrentPosition(from: currentValue) else {
        return false
      }
      if currentPosition > initialPosition + 1.0 {
        let firstValue = currentValue
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        guard let secondValue = slider.value as? String else {
          return false
        }
        if secondValue == firstValue {
          observedValue = firstValue
          return true
        }
      }
      return false
    }

    return advanced ? observedValue : nil
  }

  /// Wait for the slider value to change after a seek and then stabilize.
  func waitForUIStabilization(
    afterSeekingFrom initialValue: String?,
    timeout: TimeInterval = 3.0,
    minimumDelta: TimeInterval = 3.0,
    stabilityWindow: TimeInterval = 0.3
  ) -> String? {
    guard let slider = progressSlider() else {
      return nil
    }
    guard slider.waitForExistence(timeout: adaptiveShortTimeout) else {
      return nil
    }

    let deadline = Date().addingTimeInterval(timeout)
    let initialPosition = extractCurrentPosition(from: initialValue)

    // Wait for the slider to reflect a new position
    let changeObserved = waitForState(
      timeout: timeout,
      pollInterval: 0.1,
      description: "slider value change"
    ) {
      guard let value = slider.value as? String else { return false }

      if let initialPosition {
        guard let currentPosition = self.extractCurrentPosition(from: value) else {
          return false
        }
        return abs(currentPosition - initialPosition) >= minimumDelta
      }

      return value != initialValue
    }

    guard changeObserved else { return nil }

    let remainingTimeout = max(0.1, deadline.timeIntervalSinceNow)
    guard slider.waitForValueStable(
      timeout: remainingTimeout,
      stabilityWindow: stabilityWindow,
      checkInterval: 0.05
    ) else {
      return nil
    }

    return slider.value as? String
  }

  /// Verify position remains stable (hasn't advanced) over a period.
  func verifyPositionStable(
    at expectedValue: String?,
    forDuration: TimeInterval = 2.0,
    tolerance: TimeInterval = 0.1
  ) -> Bool {
    guard let slider = progressSlider() else {
      return false
    }
    guard slider.waitForExistence(timeout: adaptiveShortTimeout) else { return false }

    guard let expectedPosition = extractCurrentPosition(from: expectedValue) else {
      return false
    }

    let deadline = Date().addingTimeInterval(forDuration)
    var observedWithinTolerance = false

    while Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))

      guard let currentValue = slider.value as? String,
            let currentPosition = extractCurrentPosition(from: currentValue) else {
        continue
      }

      let deviation = abs(currentPosition - expectedPosition)
      if deviation > tolerance {
        return false  // Position drifted beyond tolerance
      }

      observedWithinTolerance = true
    }

    return observedWithinTolerance
  }

  // MARK: - Logging Helpers

  func logSliderValue(_ label: String, value: String?) {
    guard ProcessInfo.processInfo.environment["UITEST_POSITION_DEBUG"] == "1" else { return }
    let resolvedValue = value ?? "nil"
    Self.logger.info("\(label, privacy: .public): \(resolvedValue, privacy: .public)")
  }

  func logBreadcrumb(_ message: String) {
    guard ProcessInfo.processInfo.environment["UITEST_POSITION_DEBUG"] == "1" else { return }
    Self.logger.info("\(message, privacy: .public)")
  }

  // MARK: - State Waiting Helper

  /// Poll for a condition until true or timeout.
  private func waitForState(
    timeout: TimeInterval,
    pollInterval: TimeInterval,
    description: String,
    condition: () -> Bool
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
    }
    return condition()
  }
}

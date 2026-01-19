//
//  PlayerScreen.swift
//  zpodUITests
//
//  Created for Issue #12.3 - UI Test Infrastructure Cleanup
//
//  Page object describing the Now Playing surface
//

import Foundation
import XCTest

/// Page object that represents the playback interface and exposes the common element candidates.
@MainActor
public struct PlayerScreen: BaseScreen {
  public let app: XCUIApplication

  private var speedControlButton: XCUIElement {
    app.buttons.matching(identifier: "Speed Control").firstMatch
  }

  private var playButtonPredicate: NSPredicate {
    NSPredicate(format: "label CONTAINS[c] 'play' OR identifier CONTAINS[c] 'play'")
  }

  private func playButtonCandidates() -> [XCUIElement] {
    [
      app.buttons.matching(playButtonPredicate).firstMatch,
      app.descendants(matching: .any).matching(playButtonPredicate).firstMatch,
    ]
  }

  private func playerInterfaceCandidates() -> [XCUIElement] {
    [
      speedControlButton,
      app.otherElements.matching(identifier: "Player Interface").firstMatch,
      app.sliders.matching(identifier: "Progress Slider").firstMatch,
      app.staticTexts.matching(identifier: "Episode Title").firstMatch,
      app.staticTexts.matching(identifier: "Podcast Title").firstMatch,
    ]
  }

  /// Waits for the player surface to be ready for interaction.
  public func waitForPlayerInterface(timeout: TimeInterval? = nil) -> Bool {
    waitForAny(playerInterfaceCandidates(), timeout: timeout) != nil
  }

  /// Verifies the play button or any element labeled "Play" exists.
  public func waitForPlayButton(timeout: TimeInterval? = nil) -> XCUIElement? {
    waitForAny(playButtonCandidates(), timeout: timeout)
  }

  /// Detects elements by either identifier or label regardless of their type.
  public func exists(identifierOrLabel text: String) -> Bool {
    let predicate = NSPredicate(format: "identifier == %@ OR label == %@", text, text)
    return app.descendants(matching: .any).matching(predicate).firstMatch.exists
  }
}

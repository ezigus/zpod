//
//  SwipeActionHandler.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Extracts swipe action coordination and haptic feedback
//

import CoreModels
import Foundation
import SettingsDomain
import SharedUtilities

// MARK: - Protocol

/// Handles swipe action execution and haptic feedback
@MainActor
public protocol SwipeActionHandling: AnyObject {
  /// Perform a swipe action on an episode
  func performSwipeAction(
    _ action: SwipeActionType,
    for episode: Episode,
    quickPlayHandler: @escaping (Episode) async -> Void,
    downloadHandler: @escaping (Episode) -> Void,
    markPlayedHandler: @escaping (Episode) -> Void,
    markUnplayedHandler: @escaping (Episode) -> Void,
    playlistSelectionHandler: @escaping (Episode) -> Void,
    favoriteToggleHandler: @escaping (Episode) -> Void,
    archiveToggleHandler: @escaping (Episode) -> Void,
    deleteHandler: @escaping (Episode) async -> Void,
    shareHandler: @escaping (Episode) -> Void
  )
  
  /// Trigger haptic feedback if enabled
  func triggerHapticIfNeeded(configuration: SwipeConfiguration)
}

// MARK: - Implementation

/// Default implementation of swipe action handling
@MainActor
public final class SwipeActionHandler: SwipeActionHandling {
  private let hapticsService: HapticFeedbackServicing
  
  public init(hapticFeedbackService: HapticFeedbackServicing = HapticFeedbackService.shared) {
    self.hapticsService = hapticFeedbackService
  }
  
  public func performSwipeAction(
    _ action: SwipeActionType,
    for episode: Episode,
    quickPlayHandler: @escaping (Episode) async -> Void,
    downloadHandler: @escaping (Episode) -> Void,
    markPlayedHandler: @escaping (Episode) -> Void,
    markUnplayedHandler: @escaping (Episode) -> Void,
    playlistSelectionHandler: @escaping (Episode) -> Void,
    favoriteToggleHandler: @escaping (Episode) -> Void,
    archiveToggleHandler: @escaping (Episode) -> Void,
    deleteHandler: @escaping (Episode) async -> Void,
    shareHandler: @escaping (Episode) -> Void
  ) {
    switch action {
    case .play:
      Task {
        await quickPlayHandler(episode)
      }
    case .download:
      downloadHandler(episode)
    case .markPlayed:
      markPlayedHandler(episode)
    case .markUnplayed:
      markUnplayedHandler(episode)
    case .addToPlaylist:
      playlistSelectionHandler(episode)
    case .favorite:
      favoriteToggleHandler(episode)
    case .archive:
      archiveToggleHandler(episode)
    case .delete:
      Task {
        await deleteHandler(episode)
      }
    case .share:
      shareHandler(episode)
    }
  }
  
  public func triggerHapticIfNeeded(configuration: SwipeConfiguration) {
    guard configuration.swipeActions.hapticFeedbackEnabled else { return }
    let intensity = HapticFeedbackIntensity(style: configuration.hapticStyle)
    hapticsService.impact(intensity)
  }
}

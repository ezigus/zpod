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

// MARK: - Callback Container

/// Groups the closures needed to process swipe actions so the handler signature
/// remains concise and SwiftLint-compliant.
public struct SwipeActionCallbacks {
  public let quickPlay: (Episode) async -> Void
  public let download: (Episode) -> Void
  public let markPlayed: (Episode) -> Void
  public let markUnplayed: (Episode) -> Void
  public let selectPlaylist: (Episode) -> Void
  public let toggleFavorite: (Episode) -> Void
  public let toggleArchive: (Episode) -> Void
  public let deleteEpisode: (Episode) async -> Void
  public let shareEpisode: (Episode) -> Void

  public init(
    quickPlay: @escaping (Episode) async -> Void = { _ in },
    download: @escaping (Episode) -> Void = { _ in },
    markPlayed: @escaping (Episode) -> Void = { _ in },
    markUnplayed: @escaping (Episode) -> Void = { _ in },
    selectPlaylist: @escaping (Episode) -> Void = { _ in },
    toggleFavorite: @escaping (Episode) -> Void = { _ in },
    toggleArchive: @escaping (Episode) -> Void = { _ in },
    deleteEpisode: @escaping (Episode) async -> Void = { _ in },
    shareEpisode: @escaping (Episode) -> Void = { _ in }
  ) {
    self.quickPlay = quickPlay
    self.download = download
    self.markPlayed = markPlayed
    self.markUnplayed = markUnplayed
    self.selectPlaylist = selectPlaylist
    self.toggleFavorite = toggleFavorite
    self.toggleArchive = toggleArchive
    self.deleteEpisode = deleteEpisode
    self.shareEpisode = shareEpisode
  }
}

// MARK: - Protocol

/// Handles swipe action execution and haptic feedback
@MainActor
public protocol SwipeActionHandling: AnyObject {
  /// Perform a swipe action on an episode
  func performSwipeAction(
    _ action: SwipeActionType,
    for episode: Episode,
    callbacks: SwipeActionCallbacks
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
    callbacks: SwipeActionCallbacks
  ) {
    switch action {
    case .play:
      Task {
        await callbacks.quickPlay(episode)
      }
    case .download:
      callbacks.download(episode)
    case .markPlayed:
      callbacks.markPlayed(episode)
    case .markUnplayed:
      callbacks.markUnplayed(episode)
    case .addToPlaylist:
      callbacks.selectPlaylist(episode)
    case .favorite:
      callbacks.toggleFavorite(episode)
    case .archive:
      callbacks.toggleArchive(episode)
    case .delete:
      Task {
        await callbacks.deleteEpisode(episode)
      }
    case .share:
      callbacks.shareEpisode(episode)
    }
  }
  
  public func triggerHapticIfNeeded(configuration: SwipeConfiguration) {
    guard configuration.swipeActions.hapticFeedbackEnabled else { return }
    let intensity = HapticFeedbackIntensity(style: configuration.hapticStyle)
    hapticsService.impact(intensity)
  }
}

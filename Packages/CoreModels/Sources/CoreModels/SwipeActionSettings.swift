//
//  SwipeActionSettings.swift
//  CoreModels
//
//  Created for Issue 02.1.6: Swipe Gestures and Quick Actions
//

import Foundation

/// Available swipe action types for episode list gestures
public enum SwipeActionType: String, Codable, CaseIterable, Sendable {
  case play
  case download
  case markPlayed
  case markUnplayed
  case addToPlaylist
  case favorite
  case archive
  case delete
  case share

  /// Display name for the action
  public var displayName: String {
    switch self {
    case .play: return "Play"
    case .download: return "Download"
    case .markPlayed: return "Mark Played"
    case .markUnplayed: return "Mark Unplayed"
    case .addToPlaylist: return "Add to Playlist"
    case .favorite: return "Favorite"
    case .archive: return "Archive"
    case .delete: return "Delete"
    case .share: return "Share"
    }
  }

  /// System icon for the action
  public var systemIcon: String {
    switch self {
    case .play: return "play.fill"
    case .download: return "arrow.down.circle.fill"
    case .markPlayed: return "checkmark.circle.fill"
    case .markUnplayed: return "circle"
    case .addToPlaylist: return "text.badge.plus"
    case .favorite: return "star.fill"
    case .archive: return "archivebox.fill"
    case .delete: return "trash.fill"
    case .share: return "square.and.arrow.up"
    }
  }

  /// Color tint for the action
  public var colorTint: SwipeActionColor {
    switch self {
    case .play: return .blue
    case .download: return .blue
    case .markPlayed: return .green
    case .markUnplayed: return .gray
    case .addToPlaylist: return .orange
    case .favorite: return .yellow
    case .archive: return .purple
    case .delete: return .red
    case .share: return .blue
    }
  }

  /// Whether this action is destructive
  public var isDestructive: Bool {
    switch self {
    case .delete: return true
    default: return false
    }
  }
}

/// Color representation for swipe actions (platform-agnostic)
public enum SwipeActionColor: String, Codable, Sendable {
  case blue
  case green
  case yellow
  case orange
  case purple
  case red
  case gray
}

/// Configuration for swipe gesture actions on episode list
public struct SwipeActionSettings: Codable, Equatable, Sendable {
  /// Actions for left swipe (leading edge)
  public let leadingActions: [SwipeActionType]

  /// Actions for right swipe (trailing edge)
  public let trailingActions: [SwipeActionType]

  /// Whether to allow full swipe on leading edge
  public let allowFullSwipeLeading: Bool

  /// Whether to allow full swipe on trailing edge
  public let allowFullSwipeTrailing: Bool

  /// Whether haptic feedback is enabled
  public let hapticFeedbackEnabled: Bool

  public init(
    leadingActions: [SwipeActionType],
    trailingActions: [SwipeActionType],
    allowFullSwipeLeading: Bool = true,
    allowFullSwipeTrailing: Bool = false,
    hapticFeedbackEnabled: Bool = true
  ) {
    // Validate and limit to max 3 actions per edge
    self.leadingActions = Array(leadingActions.prefix(3))
    self.trailingActions = Array(trailingActions.prefix(3))
    self.allowFullSwipeLeading = allowFullSwipeLeading
    self.allowFullSwipeTrailing = allowFullSwipeTrailing
    self.hapticFeedbackEnabled = hapticFeedbackEnabled
  }

  /// Default swipe action settings
  public static let `default` = SwipeActionSettings(
    leadingActions: [.markPlayed],
    trailingActions: [.delete, .archive],
    allowFullSwipeLeading: true,
    allowFullSwipeTrailing: false,
    hapticFeedbackEnabled: true
  )

  /// Preset: Playback-focused configuration
  public static let playbackFocused = SwipeActionSettings(
    leadingActions: [.play, .addToPlaylist],
    trailingActions: [.download, .favorite],
    allowFullSwipeLeading: true,
    allowFullSwipeTrailing: false,
    hapticFeedbackEnabled: true
  )

  /// Preset: Organization-focused configuration
  public static let organizationFocused = SwipeActionSettings(
    leadingActions: [.markPlayed, .favorite],
    trailingActions: [.archive, .delete],
    allowFullSwipeLeading: true,
    allowFullSwipeTrailing: false,
    hapticFeedbackEnabled: true
  )

  /// Preset: Download-focused configuration
  public static let downloadFocused = SwipeActionSettings(
    leadingActions: [.download, .markPlayed],
    trailingActions: [.archive, .delete],
    allowFullSwipeLeading: true,
    allowFullSwipeTrailing: false,
    hapticFeedbackEnabled: true
  )
}

/// Haptic feedback style for swipe interactions
public enum SwipeHapticStyle: String, Codable, Sendable, CaseIterable {
  case light
  case medium
  case heavy
  case soft
  case rigid

  /// Human-readable description
  public var description: String {
    switch self {
    case .light: return "Light"
    case .medium: return "Medium"
    case .heavy: return "Heavy"
    case .soft: return "Soft"
    case .rigid: return "Rigid"
    }
  }
}

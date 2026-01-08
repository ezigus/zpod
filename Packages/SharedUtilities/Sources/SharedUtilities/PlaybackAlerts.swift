//
//  PlaybackAlerts.swift
//  SharedUtilities
//
//  Shared playback alert descriptors and presenter infrastructure.
//

import Foundation
import Combine

// MARK: - Alert Descriptor & Style

public enum PlaybackAlertStyle: Sendable {
  case info
  case warning
  case error
}

public struct PlaybackAlertDescriptor: Sendable {
  public var title: String
  public var message: String
  public var style: PlaybackAlertStyle

  public init(title: String, message: String, style: PlaybackAlertStyle) {
    self.title = title
    self.message = message
    self.style = style
  }
}

// MARK: - Actions & State

@MainActor
public struct PlaybackAlertAction {
  public let title: String
  private let handler: () -> Void

  public init(title: String, handler: @escaping () -> Void) {
    self.title = title
    self.handler = handler
  }

  public func perform() {
    handler()
  }
}

@MainActor
public struct PlaybackAlertState: Identifiable {
  public let id = UUID()
  public let descriptor: PlaybackAlertDescriptor
  public let primaryAction: PlaybackAlertAction?
  public let secondaryAction: PlaybackAlertAction?

  public init(
    descriptor: PlaybackAlertDescriptor,
    primaryAction: PlaybackAlertAction? = nil,
    secondaryAction: PlaybackAlertAction? = nil
  ) {
    self.descriptor = descriptor
    self.primaryAction = primaryAction
    self.secondaryAction = secondaryAction
  }
}

// MARK: - Presenter

@MainActor
public final class PlaybackAlertPresenter: ObservableObject {
  @Published public private(set) var currentAlert: PlaybackAlertState?

  public init() {}

  public func showAlert(
    _ descriptor: PlaybackAlertDescriptor,
    primaryAction: PlaybackAlertAction? = nil,
    secondaryAction: PlaybackAlertAction? = nil
  ) {
    currentAlert = PlaybackAlertState(
      descriptor: descriptor,
      primaryAction: primaryAction,
      secondaryAction: secondaryAction
    )
  }

  public func dismissAlert() {
    currentAlert = nil
  }

  public func performPrimaryAction() {
    guard let action = currentAlert?.primaryAction else {
      dismissAlert()
      return
    }
    action.perform()
    dismissAlert()
  }

  public func performSecondaryAction() {
    guard let action = currentAlert?.secondaryAction else {
      dismissAlert()
      return
    }
    action.perform()
    dismissAlert()
  }
}

// MARK: - Playback Error Mapping

public enum PlaybackError: Equatable, Sendable {
  // Existing cases
  case episodeUnavailable
  case resumeStateExpired
  case persistenceCorrupted
  case streamFailed
  case unknown(message: String?)

  // NEW: Network/URL errors (Issue 03.3.4.1)
  case missingAudioURL
  case networkError
  case timeout
}

public extension PlaybackError {
  /// Indicates whether this error can be recovered from by user action (e.g., retry).
  var isRecoverable: Bool {
    switch self {
    case .networkError, .timeout:
      return true  // User can retry these errors
    case .missingAudioURL, .episodeUnavailable, .resumeStateExpired, .persistenceCorrupted, .streamFailed, .unknown:
      return false  // Cannot recover from these errors
    }
  }

  /// User-facing error message suitable for display in UI.
  var userMessage: String {
    switch self {
    case .missingAudioURL:
      return "This episode doesn't have audio available"
    case .networkError:
      return "Unable to load episode. Check your connection."
    case .timeout:
      return "Loading timed out. Tap to retry."
    case .episodeUnavailable:
      return "The episode you were listening to is no longer available."
    case .resumeStateExpired:
      return "Your previous listening session expired."
    case .persistenceCorrupted:
      return "We couldn't access your last listening position."
    case .streamFailed:
      return "Playback failed. Please try again."
    case .unknown(let message):
      return message ?? "An unknown error occurred"
    }
  }

  func descriptor() -> PlaybackAlertDescriptor {
    switch self {
    case .missingAudioURL:
      return PlaybackAlertDescriptor(
        title: "Audio Not Available",
        message: userMessage,
        style: .error
      )
    case .networkError:
      return PlaybackAlertDescriptor(
        title: "Connection Error",
        message: userMessage,
        style: .error
      )
    case .timeout:
      return PlaybackAlertDescriptor(
        title: "Request Timed Out",
        message: userMessage,
        style: .error
      )
    case .episodeUnavailable:
      return PlaybackAlertDescriptor(
        title: "Episode Unavailable",
        message: "The episode you were listening to is no longer available.",
        style: .error
      )
    case .resumeStateExpired:
      return PlaybackAlertDescriptor(
        title: "Session Expired",
        message: "Your previous listening session expired. Start playing again to continue.",
        style: .warning
      )
    case .persistenceCorrupted:
      return PlaybackAlertDescriptor(
        title: "Playback Data Error",
        message: "We couldn’t access your last listening position. Please try again.",
        style: .error
      )
    case .streamFailed:
      return PlaybackAlertDescriptor(
        title: "Playback Failed",
        message: "The audio stream encountered a problem. Retry to continue.",
        style: .error
      )
    case .unknown(let message):
      return PlaybackAlertDescriptor(
        title: "Playback Issue",
        message: message ?? "Something went wrong during playback.",
        style: .warning
      )
    }
  }
}

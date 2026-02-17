import Foundation

/// Helper generating pre-seeded swipe configurations for UI tests.
public enum SwipeConfigurationSeeding {
  /// Encodes a swipe configuration payload as base64 so tests can seed `UITEST_SEEDED_SWIPE_CONFIGURATION_B64`.
  public static func base64(
    leading: [String],
    trailing: [String],
    allowFullSwipeLeading: Bool = true,
    allowFullSwipeTrailing: Bool = false,
    hapticsEnabled: Bool = true,
    hapticStyle: String = "medium"
  ) -> String {
    let payload: [String: Any] = [
      "swipeActions": [
        "leadingActions": leading,
        "trailingActions": trailing,
        "allowFullSwipeLeading": allowFullSwipeLeading,
        "allowFullSwipeTrailing": allowFullSwipeTrailing,
        "hapticFeedbackEnabled": hapticsEnabled
      ],
      "hapticStyle": hapticStyle
    ]

    guard JSONSerialization.isValidJSONObject(payload),
          let data = try? JSONSerialization.data(withJSONObject: payload, options: [])
    else {
      fatalError("SwipeConfigurationSeeding: failed to encode payload")
    }

    return data.base64EncodedString()
  }

  /// Download-focused configuration exposing the download/delete actions needed by offline tests.
  public static var downloadFocused: String {
    base64(
      leading: ["download", "markPlayed"],
      trailing: ["deleteDownload", "archive", "delete"]
    )
  }

  /// Cancel-download-focused configuration exposing the cancel action for in-progress download tests.
  public static var cancelDownloadFocused: String {
    base64(
      leading: ["download", "markPlayed"],
      trailing: ["cancelDownload", "deleteDownload", "delete"]
    )
  }

  /// Factory for a custom swipe configuration payload.
  public static func custom(
    leading: [String],
    trailing: [String],
    allowFullSwipeLeading: Bool = true,
    allowFullSwipeTrailing: Bool = false,
    hapticsEnabled: Bool = true,
    hapticStyle: String = "medium"
  ) -> String {
    base64(
      leading: leading,
      trailing: trailing,
      allowFullSwipeLeading: allowFullSwipeLeading,
      allowFullSwipeTrailing: allowFullSwipeTrailing,
      hapticsEnabled: hapticsEnabled,
      hapticStyle: hapticStyle
    )
  }
}

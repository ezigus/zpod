import Foundation

public enum UITestTabSelection {
  public static func resolve(
    rawValue: String?,
    defaultIndex: Int = 0,
    maxIndex: Int,
    mapping: [String: Int]
  ) -> Int {
    guard let rawValue, !rawValue.isEmpty else { return defaultIndex }
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return defaultIndex }

    if let numericValue = Int(trimmed) {
      return min(max(numericValue, 0), maxIndex)
    }

    let normalized = trimmed.lowercased()
    if let mapped = mapping[normalized] {
      return min(max(mapped, 0), maxIndex)
    }

    return defaultIndex
  }
}

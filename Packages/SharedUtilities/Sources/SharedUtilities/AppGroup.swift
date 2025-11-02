import Foundation

/// Shared App Group identifiers used across the zpod app, extensions, and supporting utilities.
public enum AppGroup {
    /// Primary suite identifier used for sharing data between the main app and extensions.
    public static let suiteName = "group.us.zig.zpod"
    /// Development/testing suite identifier for local tooling and UI test injectors.
    public static let devSuiteName = "dev.us.zig.zpod"
}

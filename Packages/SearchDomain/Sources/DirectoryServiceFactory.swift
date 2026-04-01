import Foundation

/// Builds the external podcast directory service for production use.
///
/// Centralising construction here removes duplication between `ContentView.swift`
/// (LibraryFeature) and `ContentViewBridge.swift` (app target) and ensures both
/// sites apply the UI-test disable gate consistently.
public struct DirectoryServiceFactory {

    /// Launch-environment key that, when set to `"1"`, disables external directory search.
    ///
    /// The test-side constant `UITestLaunchConfiguration.directorySearchDisabledKey` in
    /// `zpodUITests/UITestLaunchConfiguration.swift` must equal this value.
    public static let uitestDisableKey = "UITEST_DISABLE_DIRECTORY_SEARCH"

    /// Builds the default production directory service, or `nil` when disabled by the
    /// `UITEST_DISABLE_DIRECTORY_SEARCH` launch-environment flag.
    ///
    /// - Parameters:
    ///   - podcastIndexAPIKey: Optional PodcastIndex API key (read from xcconfig).
    ///   - podcastIndexAPISecret: Optional PodcastIndex API secret.
    /// - Returns: iTunes-only provider, aggregate provider when PodcastIndex credentials
    ///   are present, or `nil` in UI-test environments.
    public static func makeDefault(
        podcastIndexAPIKey: String?,
        podcastIndexAPISecret: String?
    ) -> (any PodcastDirectorySearching)? {
        guard ProcessInfo.processInfo.environment[uitestDisableKey] != "1" else { return nil }

        let iTunes = ITunesSearchProvider()
        var providers: [any PodcastDirectorySearching] = [iTunes]

        if let podcastIndex = PodcastIndexSearchProvider(
            apiKey: podcastIndexAPIKey,
            apiSecret: podcastIndexAPISecret
        ) {
            providers.append(podcastIndex)
        }

        if providers.count == 1 { return providers[0] }
        return AggregateSearchProvider(providers: providers)
    }
}

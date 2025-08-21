// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "zpod",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11)
    ],
    products: [
        // Main library for cross-platform development
        .library(
            name: "zpodLib",
            targets: ["zpodLib"]
        ),
    ],
    dependencies: [
        // Local packages
        .package(path: "Packages/CoreModels"),
        .package(path: "Packages/SharedUtilities"),
        .package(path: "Packages/TestSupport"),
        .package(path: "Packages/Persistence"),
        .package(path: "Packages/FeedParsing"), // Re-added FeedParsing dependency
        .package(path: "Packages/Networking"),
        .package(path: "Packages/SettingsDomain"),
        // Add any external dependencies here
        // Example: .package(url: "https://github.com/realm/SwiftLint.git", from: "0.50.0")
    ],
    targets: [
        // Main library target containing core logic
        .target(
            name: "zpodLib",
            dependencies: [
                "CoreModels",
                "SharedUtilities", 
                "Persistence",
                "FeedParsing", // Re-added FeedParsing dependency
                "Networking",
                "SettingsDomain"
            ],
            path: "zpod",
            exclude: [
                // Exclude iOS/SwiftUI specific files that won't compile on Linux
                "zpodApp.swift",
                "ContentView.swift",
                "Item.swift", // Uses SwiftData which is iOS-only
                "Views/", // Uses SwiftUI
                "ViewModels/", // Uses SwiftUI
                "Controllers/", // Has dependencies on Services
                "Services/", // Will be moved to domain packages
                "Assets.xcassets", // Asset catalog
                "Preview Content",
                "Info.plist",
                "zpod.entitlements",
                "README.md",
                "spec/",
                ".github/",
                ".vscode/"
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        
        // Test target
        .testTarget(
            name: "zpodTests",
            dependencies: [
                "zpodLib",
                "TestSupport"
            ],
            path: "zpodTests",
            exclude: [
                // Exclude tests that depend on Combine/UI services which are not in zpodLib
                "InMemoryPlaylistManager.swift",
                "Issue01SubscribeTests.swift",
                "Issue02EpisodeDetailTests.swift", 
                "Issue03AdvancedControlsTests.swift",
                "Issue03PlaybackEngineTests.swift",
                "Issue04DownloadTests.swift",
                "Issue05AcceptanceCriteriaTests.swift",
                "Issue05SettingsIntegrationTests.swift",
                "Issue05SettingsTests.swift",
                "Issue06PlaylistTests.swift",
                "Issue07FolderTagTests.swift",
                "Issue08SearchTests.swift",
                "Issue10AcceptanceCriteriaTests.swift",
                "Issue10UpdateFrequencyTests.swift",
                "Issue11OPMLTests.swift",
                "PodcastTests.swift" // Uses old zpod module
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
    ]
)

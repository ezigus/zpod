// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "zpod",
    platforms: [
        .iOS(.v18),
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
        .package(path: "Packages/SearchDomain"),
        .package(path: "Packages/RecommendationDomain"),
        .package(path: "Packages/PlaybackEngine"),
        // UI Feature packages
        .package(path: "Packages/LibraryFeature"),
        .package(path: "Packages/PlayerFeature"),
        .package(path: "Packages/DiscoverFeature"),
        .package(path: "Packages/PlaylistFeature")
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
                "SettingsDomain",
                "SearchDomain",
                "RecommendationDomain",
                "PlaybackEngine",
                // UI Feature packages (optional for lib)
                "LibraryFeature",
                "PlayerFeature",
                "DiscoverFeature",
                "PlaylistFeature"
            ],
            path: "zpod",
            exclude: [
                // Exclude iOS/SwiftUI specific files that won't compile on Linux
                "zpodApp.swift",
                "Controllers/", // Has dependencies on Services
                "Assets.xcassets", // Asset catalog
                "Preview Content",
                "Info.plist",
                "zpod.entitlements",
                "README.md",
                "spec/",
                ".vscode/"
            ]
        ),
        
        // Test target
        .testTarget(
            name: "zpodTests", 
            dependencies: [
                "zpodLib",
                "TestSupport"
            ],
            path: "zpodTests"
        ),
        
        // Integration test target
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "zpodLib",
                "TestSupport"
            ],
            path: "IntegrationTests"
        ),
    ]
)

// TODO: [Issue #12.5] Add cross-platform testing support for package tests
// This would enable testing of core packages on non-Apple platforms while excluding iOS-specific frameworks

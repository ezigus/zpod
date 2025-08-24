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
                "SearchDomain"
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
                "Assets.xcassets", // Asset catalog
                "Preview Content",
                "Info.plist",
                "zpod.entitlements",
                "README.md",
                "spec/",
                ".github/",
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
            path: "Tests/zpodTests"
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

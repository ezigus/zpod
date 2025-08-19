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
        // Add any external dependencies here
        // Example: .package(url: "https://github.com/realm/SwiftLint.git", from: "0.50.0")
    ],
    targets: [
        // Main library target containing core logic
        .target(
            name: "zpodLib",
            dependencies: [
                "CoreModels",
                "SharedUtilities"
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
                "instructions.md",
                "spec/",
                ".github/",
                ".vscode/",
                "Models/", // Models are now in CoreModels package
                // Exclude services that use Combine (not available on Linux)
                "Services/AVFoundationAudioPlayer.swift",
                "Services/DownloadCoordinator.swift",
                "Services/DownloadQueueManager.swift",
                "Services/EnhancedEpisodePlayer.swift",
                "Services/EpisodePlaybackService.swift",
                "Services/FileManagerService.swift",
                "Services/PlaylistEngine.swift",
                "Services/SettingsManager.swift",
                "Services/SettingsRepository.swift",
                "Services/SleepTimer.swift",
                "Services/UpdateFrequencyService.swift"
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
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
    ]
)
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "zpod",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "zpodLib", targets: ["zpodLib"]),
    ],
    dependencies: [
        .package(path: "Packages/CoreModels"),
        .package(path: "Packages/SharedUtilities"),
        .package(path: "Packages/TestSupport"),
        .package(path: "Packages/Persistence"),
        .package(path: "Packages/FeedParsing"),
        .package(path: "Packages/Networking"),
        .package(path: "Packages/SettingsDomain"),
        .package(path: "Packages/SearchDomain"),
        .package(path: "Packages/RecommendationDomain"),
        .package(path: "Packages/PlaybackEngine"),
        .package(path: "Packages/LibraryFeature"),
        .package(path: "Packages/PlayerFeature"),
        .package(path: "Packages/DiscoverFeature"),
        .package(path: "Packages/PlaylistFeature"),
        .package(path: "Packages/CombineSupport"),
    ],
    targets: [
        .target(
            name: "zpodLib",
            dependencies: [
                "CoreModels",
                "SharedUtilities",
                "Persistence",
                "FeedParsing",
                "Networking",
                "SettingsDomain",
                "SearchDomain",
                "RecommendationDomain",
                "PlaybackEngine",
                "LibraryFeature",
                "PlayerFeature",
                "DiscoverFeature",
                "PlaylistFeature",
            ],
            path: "zpod",
            exclude: [
                "ZpodApp.swift",
                "Controllers/",
                "Assets.xcassets",
                "Preview Content",
                "Info.plist",
                "zpod.entitlements",
                "README.md",
                "spec/",
                ".vscode/",
            ]
        ),
        .testTarget(
            name: "AppSmokeTests",
            dependencies: ["zpodLib", "SharedUtilities", "TestSupport"],
            path: "AppSmokeTests"
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "zpodLib",
                "TestSupport",
                "SettingsDomain",
                "Persistence"
            ],
            path: "IntegrationTests"
        ),
    ]
)

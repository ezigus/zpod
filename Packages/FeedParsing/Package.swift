// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FeedParsing",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "FeedParsing",
            targets: ["FeedParsing"]
        ),
    ],
    dependencies: [
        .package(path: "../CoreModels"),
        .package(path: "../SharedUtilities")
    ],
    targets: [
        .target(
            name: "FeedParsing",
            dependencies: [
                "CoreModels",
                "SharedUtilities"
            ],
            path: "Sources"
        )
    ]
)

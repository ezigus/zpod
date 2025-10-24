// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RecommendationDomain",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "RecommendationDomain",
            targets: ["RecommendationDomain"]
        ),
    ],
    dependencies: [
        .package(path: "../CoreModels"),
        .package(path: "../SharedUtilities"),
        .package(path: "../TestSupport")
    ],
    targets: [
        .target(
            name: "RecommendationDomain",
            dependencies: [
                "CoreModels",
                "SharedUtilities"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "RecommendationDomainTests",
            dependencies: [
                "RecommendationDomain",
                "CoreModels",
                "SharedUtilities",
                "TestSupport"
            ]
        )
    ]
)

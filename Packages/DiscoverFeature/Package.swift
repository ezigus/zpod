// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiscoverFeature",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "DiscoverFeature",
            targets: ["DiscoverFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreModels"),
        .package(path: "../SharedUtilities")
    ],
    targets: [
        .target(
            name: "DiscoverFeature",
            dependencies: [
                .product(name: "CoreModels", package: "CoreModels"),
                .product(name: "SharedUtilities", package: "SharedUtilities")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "DiscoverFeatureTests",
            dependencies: ["DiscoverFeature"]
        )
    ]
)
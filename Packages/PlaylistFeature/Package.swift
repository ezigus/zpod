// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlaylistFeature",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "PlaylistFeature",
            targets: ["PlaylistFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreModels"),
        .package(path: "../TestSupport"),
        .package(path: "../SharedUtilities")
    ],
    targets: [
        .target(
            name: "PlaylistFeature",
            dependencies: [
                .product(name: "CoreModels", package: "CoreModels"),
                .product(name: "TestSupport", package: "TestSupport"),
                .product(name: "SharedUtilities", package: "SharedUtilities")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "PlaylistFeatureTests",
            dependencies: [
                "PlaylistFeature",
                .product(name: "TestSupport", package: "TestSupport")
            ]
        )
    ]
)
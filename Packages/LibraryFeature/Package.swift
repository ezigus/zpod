// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LibraryFeature",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "LibraryFeature",
            targets: ["LibraryFeature"]),
    ],
    dependencies: [
        .package(path: "../CoreModels"),
        .package(path: "../SharedUtilities"),
        .package(path: "../DiscoverFeature"),
        .package(path: "../PlayerFeature"),
        .package(path: "../PlaylistFeature")
    ],
    targets: [
        .target(
            name: "LibraryFeature",
            dependencies: [
                .product(name: "CoreModels", package: "CoreModels"),
                .product(name: "SharedUtilities", package: "SharedUtilities"),
                .product(name: "DiscoverFeature", package: "DiscoverFeature"),
                .product(name: "PlayerFeature", package: "PlayerFeature"),
                .product(name: "PlaylistFeature", package: "PlaylistFeature")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "LibraryFeatureTests",
            dependencies: ["LibraryFeature"]
        )
    ]
)
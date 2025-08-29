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
        .package(path: "../SharedUtilities")
    ],
    targets: [
        .target(
            name: "LibraryFeature",
            dependencies: [
                .product(name: "CoreModels", package: "CoreModels"),
                .product(name: "SharedUtilities", package: "SharedUtilities")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "LibraryFeatureTests",
            dependencies: ["LibraryFeature"]
        )
    ]
)
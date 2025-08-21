// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreModels",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "CoreModels",
            targets: ["CoreModels"]),
    ],
    dependencies: [
        .package(path: "../../PlaybackEngine")
    ],
    targets: [
        .target(
            name: "CoreModels",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "CoreModelsTests",
            dependencies: [
                "CoreModels",
                .product(name: "PlaybackEngine", package: "PlaybackEngine")
            ]
         )
    ]
)

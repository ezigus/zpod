// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SettingsDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SettingsDomain",
            targets: ["SettingsDomain"]),
    ],
    dependencies: [
        .package(path: "../CoreModels"),
        .package(path: "../SharedUtilities"),
        .package(path: "../Persistence")
    ],
    targets: [
        .target(
            name: "SettingsDomain",
            dependencies: [
                .product(name: "CoreModels", package: "CoreModels"),
                .product(name: "SharedUtilities", package: "SharedUtilities"),
                .product(name: "Persistence", package: "Persistence")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SettingsDomainTests",
            dependencies: ["SettingsDomain"])
    ]
)
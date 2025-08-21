// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SharedUtilities",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "SharedUtilities", targets: ["SharedUtilities"]) 
    ],
    targets: [
        .target(
            name: "SharedUtilities",
            path: "Sources"
        ),
        .testTarget(
            name: "SharedUtilitiesTests",
            dependencies: ["SharedUtilities"]
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TestSupport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "TestSupport", targets: ["TestSupport"]) 
    ],
    dependencies: [
        .package(path: "../CoreModels")
    ],
    targets: [
        .target(
            name: "TestSupport",
            dependencies: [
                .product(name: "CoreModels", package: "CoreModels")
            ],
            path: "Sources"
        )
    ]
)

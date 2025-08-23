// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TestSupport",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
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
        ),
        .testTarget(
            name: "TestSupportTests",
            dependencies: [
                "TestSupport",
                .product(name: "CoreModels", package: "CoreModels")
            ],
            path: "Tests"
        )
    ]
)

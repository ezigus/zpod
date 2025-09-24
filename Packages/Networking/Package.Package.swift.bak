// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "Networking",
            targets: ["Networking"]
        ),
    ],
    dependencies: [
        .package(path: "../CoreModels"),
        .package(path: "../SharedUtilities"),
        .package(path: "../Persistence"),
        .package(path: "../TestSupport")
    ],
    targets: [
        .target(
            name: "Networking",
            dependencies: [
                "CoreModels",
                "SharedUtilities",
                "Persistence"
            ],
            path: "Sources",
            resources: [
                .process("SampleSubscriptions.opml")
            ]
        ),
        .testTarget(
            name: "NetworkingTests",
            dependencies: [
                "Networking",
                "CoreModels",
                "SharedUtilities",
                "TestSupport"
            ]
        )
    ]
)

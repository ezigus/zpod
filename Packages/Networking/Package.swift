// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
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
        .package(path: "../SharedUtilities")
    ],
    targets: [
        .target(
            name: "Networking",
            dependencies: [
                "CoreModels",
                "SharedUtilities"
            ],
            path: "Sources",
            resources: [
                .process("SampleSubscriptions.opml")
            ]
        )
    ]
)

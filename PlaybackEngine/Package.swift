// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PlaybackEngine",
    platforms: [
        .iOS(.v16), .macOS(.v13)
    ],
    products: [
        .library(
            name: "PlaybackEngine",
            targets: ["PlaybackEngine"]
        )
    ],
    targets: [
        .target(
            name: "PlaybackEngine",
            dependencies: [],
            path: ".",
            exclude: ["Package.swift"]
        )
    ]
)

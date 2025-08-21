// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PlaybackEngine",
    platforms: [
        .iOS(.v18), 
        .watchOS(.v11)
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

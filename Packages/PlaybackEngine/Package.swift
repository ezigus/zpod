// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "PlaybackEngine",
  platforms: [
    .iOS(.v18),
    .macOS(.v14),
    .watchOS(.v11),
  ],
  products: [
    .library(
      name: "PlaybackEngine",
      targets: ["PlaybackEngine"]
    )
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../SharedUtilities"),
    .package(path: "../CombineSupport"),
    .package(path: "../TestSupport"),
  ],
  targets: [
    .target(
      name: "PlaybackEngine",
      dependencies: [
        "CoreModels",
        "CombineSupport"
      ],
      path: ".",
      exclude: ["Package.swift", "Tests"]
    ),
    .testTarget(
      name: "PlaybackEngineTests",
      dependencies: [
        "PlaybackEngine",
        "CoreModels",
        "SharedUtilities",
        "CombineSupport",
        "TestSupport",
      ],
      path: "Tests"
    ),
  ]
)

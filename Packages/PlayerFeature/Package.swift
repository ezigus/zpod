// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PlayerFeature",
  platforms: [
    .iOS(.v18),
    .macOS(.v14),
    .watchOS(.v11),
  ],
  products: [
    .library(
      name: "PlayerFeature",
      targets: ["PlayerFeature"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../PlaybackEngine"),
    .package(path: "../Persistence"),
    .package(path: "../SharedUtilities"),
    .package(path: "../TestSupport"),
  ],
  targets: [
    .target(
      name: "PlayerFeature",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "PlaybackEngine", package: "PlaybackEngine"),
        .product(name: "Persistence", package: "Persistence"),
        .product(name: "SharedUtilities", package: "SharedUtilities"),
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "PlayerFeatureTests",
      dependencies: [
        "PlayerFeature",
        .product(name: "TestSupport", package: "TestSupport"),
      ]
    ),
  ]
)

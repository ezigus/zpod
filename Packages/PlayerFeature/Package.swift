// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PlayerFeature",
  platforms: [
    .iOS(.v18),
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
    .package(path: "../SharedUtilities"),
    .package(path: "../TestSupport"),
  ],
  targets: [
    .target(
      name: "PlayerFeature",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "PlaybackEngine", package: "PlaybackEngine"),
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

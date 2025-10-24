// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "CoreModels",
  platforms: [
    .iOS(.v18),
    .watchOS(.v11),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "CoreModels",
      targets: ["CoreModels"])
  ],
  dependencies: [
    // Remove PlaybackEngine dependency for now to focus on CoreModels tests
  ],
  targets: [
    .target(
      name: "CoreModels",
      dependencies: []
    ),
    .testTarget(
      name: "CoreModelsTests",
      dependencies: [
        "CoreModels"
      ]
    ),
  ]
)

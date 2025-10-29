// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "CoreModels",
  platforms: [
    .iOS(.v18),
    .macOS(.v14),
    .watchOS(.v11),
  ],
  products: [
    .library(
      name: "CoreModels",
      targets: ["CoreModels"])
  ],
  dependencies: [
    .package(path: "../SharedUtilities"),
  ],
  targets: [
    .target(
      name: "CoreModels",
      dependencies: [
        .product(name: "SharedUtilities", package: "SharedUtilities"),
      ]
    ),
    .testTarget(
      name: "CoreModelsTests",
      dependencies: [
        "CoreModels"
      ]
    ),
  ]
)

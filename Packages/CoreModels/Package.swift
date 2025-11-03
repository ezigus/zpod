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
    .package(path: "../CombineSupport"),
  ],
  targets: [
    .target(
      name: "CoreModels",
      dependencies: [
        .product(name: "SharedUtilities", package: "SharedUtilities"),
        .product(name: "CombineSupport", package: "CombineSupport"),
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

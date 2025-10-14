// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Persistence",
  platforms: [
    .iOS(.v18),
    .macOS(.v14),
    .watchOS(.v11),
  ],
  products: [
    .library(name: "Persistence", targets: ["Persistence"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../SharedUtilities"),
  ],
  targets: [
    .target(
      name: "Persistence",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "SharedUtilities", package: "SharedUtilities"),
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "PersistenceTests",
      dependencies: ["Persistence"]
    ),
  ]
)

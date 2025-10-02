// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SharedUtilities",
  platforms: [
    .iOS(.v18),
    .watchOS(.v11),
  ],
  products: [
    .library(name: "SharedUtilities", targets: ["SharedUtilities"])
  ],
  dependencies: [
    .package(path: "../CoreModels")
  ],
  targets: [
    .target(
      name: "SharedUtilities",
      dependencies: [
        "CoreModels"
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "SharedUtilitiesTests",
      dependencies: [
        "SharedUtilities"
      ],
      path: "Tests"
    ),
  ]
)

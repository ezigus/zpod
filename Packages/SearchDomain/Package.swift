// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SearchDomain",
  platforms: [
    .iOS(.v18),
    .macOS(.v14),
    .watchOS(.v11),
  ],
  products: [
    .library(
      name: "SearchDomain",
      targets: ["SearchDomain"]
    )
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../SharedUtilities"),
    .package(path: "../TestSupport"),
  ],
  targets: [
    .target(
      name: "SearchDomain",
      dependencies: [
        "CoreModels",
        "SharedUtilities",
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "SearchDomainTests",
      dependencies: [
        "SearchDomain",
        "CoreModels",
        "SharedUtilities",
        "TestSupport",
      ]
    ),
  ]
)

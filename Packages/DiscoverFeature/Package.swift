// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DiscoverFeature",
  platforms: [
    .iOS(.v18),
    // TODO: Add macOS support when UIKit-specific adapters are replaced with macOS-compatible alternatives
    // .macOS(.v14),
    .watchOS(.v11),
  ],
  products: [
    .library(
      name: "DiscoverFeature",
      targets: ["DiscoverFeature"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../SharedUtilities"),
    .package(path: "../SearchDomain"),
    .package(path: "../FeedParsing"),
    .package(path: "../TestSupport"),
  ],
  targets: [
    .target(
      name: "DiscoverFeature",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "SharedUtilities", package: "SharedUtilities"),
        .product(name: "SearchDomain", package: "SearchDomain"),
        .product(name: "FeedParsing", package: "FeedParsing"),
      ],
      path: "Sources"
    ),
    .testTarget(
      name: "DiscoverFeatureTests",
      dependencies: [
        "DiscoverFeature",
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "SearchDomain", package: "SearchDomain"),
        .product(name: "TestSupport", package: "TestSupport"),
      ]
    ),
  ]
)

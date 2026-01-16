// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LibraryFeature",
  platforms: [
    .iOS(.v18),
    .macOS(.v14),
    .watchOS(.v11),
  ],
  products: [
    .library(
      name: "LibraryFeature",
      targets: ["LibraryFeature"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../SharedUtilities"),
    .package(path: "../CombineSupport"),
    .package(path: "../SearchDomain"),
    .package(path: "../SettingsDomain"),
    .package(path: "../DiscoverFeature"),
    .package(path: "../PlayerFeature"),
    .package(path: "../PlaylistFeature"),
    .package(path: "../Persistence"),
    .package(path: "../PlaybackEngine"),
    .package(path: "../Networking"),
  ],
  targets: [
    .target(
      name: "LibraryFeature",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "SharedUtilities", package: "SharedUtilities"),
        .product(name: "CombineSupport", package: "CombineSupport"),
        .product(name: "SearchDomain", package: "SearchDomain"),
        .product(name: "SettingsDomain", package: "SettingsDomain"),
        .product(name: "DiscoverFeature", package: "DiscoverFeature"),
        .product(name: "PlayerFeature", package: "PlayerFeature"),
        .product(name: "PlaylistFeature", package: "PlaylistFeature"),
        .product(name: "Persistence", package: "Persistence"),
        .product(name: "PlaybackEngine", package: "PlaybackEngine"),
        .product(name: "Networking", package: "Networking"),
      ],
      path: "Sources",
      exclude: [
        "LibraryFeature/CARPLAY_README.md"
      ]
    ),
    .testTarget(
      name: "LibraryFeatureTests",
      dependencies: [
        "LibraryFeature",
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "SharedUtilities", package: "SharedUtilities"),
        .product(name: "CombineSupport", package: "CombineSupport"),
      ]
    ),
  ]
)

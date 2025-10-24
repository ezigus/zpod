// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SettingsDomain",
  platforms: [
    .iOS(.v18),
    .watchOS(.v11),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "SettingsDomain",
      targets: ["SettingsDomain"])
  ],
  dependencies: [
    .package(path: "../CoreModels"),
    .package(path: "../SharedUtilities"),
    .package(path: "../Persistence"),
  ],
  targets: [
    .target(
      name: "SettingsDomain",
      dependencies: [
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "SharedUtilities", package: "SharedUtilities"),
        .product(name: "Persistence", package: "Persistence"),
      ]
    ),
    .testTarget(
      name: "SettingsDomainTests",
      dependencies: [
        "SettingsDomain",
        .product(name: "CoreModels", package: "CoreModels"),
        .product(name: "SharedUtilities", package: "SharedUtilities"),
        .product(name: "Persistence", package: "Persistence"),
      ]),
  ]
)

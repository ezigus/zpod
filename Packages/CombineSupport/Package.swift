// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "CombineSupport",
  platforms: [
    .iOS(.v18),
    .macOS(.v14),
    .watchOS(.v11)
  ],
  products: [
    .library(name: "CombineSupport", targets: ["CombineSupport"])
  ],
  dependencies: [
    .package(url: "https://github.com/OpenCombine/OpenCombine.git", from: "0.14.0")
  ],
  targets: [
    .target(
      name: "CombineSupport",
      dependencies: [
        .product(name: "OpenCombine", package: "OpenCombine"),
        .product(name: "OpenCombineDispatch", package: "OpenCombine"),
        .product(name: "OpenCombineFoundation", package: "OpenCombine")
      ],
      path: "Sources"
    )
  ]
)

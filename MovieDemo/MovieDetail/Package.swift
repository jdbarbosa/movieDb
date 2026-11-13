// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MovieDetail",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "MovieDetail", targets: ["MovieDetail"])
  ],
  dependencies: [
    .package(path: "../Locator"),
    .package(path: "../Protocols"),
    .package(path: "../Models"),
    .package(path: "../APIClient"),
    .package(path: "../AnalyticsClient"),
    .package(path: "../MovieStore"),
    .package(path: "../MovieUI")
  ],
  targets: [
    .target(
      name: "MovieDetail",
      dependencies: ["Locator", "Protocols", "Models", "APIClient", "AnalyticsClient", "MovieStore", "MovieUI"]
    ),
    .testTarget(
      name: "MovieDetailTests",
      dependencies: [
        "MovieDetail",
        .product(name: "APIClientTesting", package: "APIClient"),
        .product(name: "AnalyticsClientTesting", package: "AnalyticsClient"),
        .product(name: "MovieStoreTesting", package: "MovieStore")
      ]
    )
  ]
)

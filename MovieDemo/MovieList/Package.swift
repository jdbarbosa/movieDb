// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MovieList",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "MovieList", targets: ["MovieList"])
  ],
  dependencies: [
    .package(path: "../Locator"),
    .package(path: "../Protocols"),
    .package(path: "../Models"),
    .package(path: "../APIClient"),
    .package(path: "../AnalyticsClient"),
    .package(path: "../MovieDetail"),
    .package(path: "../MovieUI")
  ],
  targets: [
    .target(
      name: "MovieList",
      dependencies: ["Locator", "Protocols", "Models", "APIClient", "AnalyticsClient", "MovieDetail", "MovieUI"]
    ),
    .testTarget(
      name: "MovieListTests",
      dependencies: [
        "MovieList",
        .product(name: "APIClientTesting", package: "APIClient"),
        .product(name: "AnalyticsClientTesting", package: "AnalyticsClient")
      ]
    )
  ]
)

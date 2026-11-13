// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MyMovies",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "MyMovies", targets: ["MyMovies"])
  ],
  dependencies: [
    .package(path: "../Locator"),
    .package(path: "../Protocols"),
    .package(path: "../Models"),
    .package(path: "../AnalyticsClient"),
    .package(path: "../MovieStore"),
    .package(path: "../MovieUI"),
    .package(path: "../MovieDetail")
  ],
  targets: [
    .target(
      name: "MyMovies",
      dependencies: ["Locator", "Protocols", "Models", "AnalyticsClient", "MovieStore", "MovieUI", "MovieDetail"]
    ),
    .testTarget(
      name: "MyMoviesTests",
      dependencies: [
        "MyMovies",
        .product(name: "AnalyticsClientTesting", package: "AnalyticsClient"),
        .product(name: "MovieStoreTesting", package: "MovieStore")
      ]
    )
  ]
)

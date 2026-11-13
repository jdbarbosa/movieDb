// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MovieUI",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "MovieUI", targets: ["MovieUI"])
  ],
  dependencies: [
    .package(path: "../Models"),
    .package(path: "../MovieStore")
  ],
  targets: [
    .target(name: "MovieUI", dependencies: ["Models", "MovieStore"]),
    .testTarget(name: "MovieUITests", dependencies: ["MovieUI"])
  ]
)

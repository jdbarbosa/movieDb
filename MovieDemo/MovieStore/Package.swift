// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MovieStore",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "MovieStore", targets: ["MovieStore"]),
    .library(name: "MovieStoreTesting", targets: ["MovieStoreTesting"])
  ],
  dependencies: [
    .package(path: "../Locator"),
    .package(path: "../Models")
  ],
  targets: [
    .target(name: "MovieStore", dependencies: ["Locator", "Models"]),
    .target(name: "MovieStoreTesting", dependencies: ["MovieStore"]),
    .testTarget(name: "MovieStoreTests", dependencies: ["MovieStore", "MovieStoreTesting"])
  ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "APIClient",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "APIClient", targets: ["APIClient"]),
    .library(name: "APIClientTesting", targets: ["APIClientTesting"])
  ],
  dependencies: [
    .package(path: "../Locator")
  ],
  targets: [
    .target(name: "APIClient", dependencies: ["Locator"]),
    .target(name: "APIClientTesting", dependencies: ["APIClient"]),
    .testTarget(name: "APIClientTests", dependencies: ["APIClient", "APIClientTesting"])
  ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Locator",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "Locator", targets: ["Locator"])
  ],
  targets: [
    .target(name: "Locator"),
    .testTarget(name: "LocatorTests", dependencies: ["Locator"])
  ]
)

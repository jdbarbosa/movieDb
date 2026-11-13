// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AnalyticsClient",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "AnalyticsClient", targets: ["AnalyticsClient"]),
    .library(name: "AnalyticsClientTesting", targets: ["AnalyticsClientTesting"])
  ],
  dependencies: [
    .package(path: "../Locator")
  ],
  targets: [
    .target(name: "AnalyticsClient", dependencies: ["Locator"]),
    .target(name: "AnalyticsClientTesting", dependencies: ["AnalyticsClient"]),
    .testTarget(name: "AnalyticsClientTests", dependencies: ["AnalyticsClient", "AnalyticsClientTesting"])
  ]
)

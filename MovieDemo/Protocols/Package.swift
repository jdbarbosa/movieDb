// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Protocols",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "Protocols", targets: ["Protocols"])
  ],
  targets: [
    .target(name: "Protocols"),
    .testTarget(name: "ProtocolsTests", dependencies: ["Protocols"])
  ]
)

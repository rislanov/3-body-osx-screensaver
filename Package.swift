// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "ThreeBody", platforms: [.macOS(.v14)],
  products: [.library(name: "ThreeBodyCore", targets: ["ThreeBodyCore"])],
  targets: [
    .target(name: "ThreeBodyCore", path: "Sources/Core"),
    .testTarget(name: "CoreTests", dependencies: ["ThreeBodyCore"], path: "Tests/CoreTests"),
  ])

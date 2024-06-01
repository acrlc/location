// swift-tools-version: 5.5
import PackageDescription

let package = Package(
 name: "Location",
 products: [.library(name: "Location", targets: ["Location"])],
 targets: [
  .target(name: "Location"),
  .testTarget(name: "LocationTests", dependencies: ["Location"])
 ]
)

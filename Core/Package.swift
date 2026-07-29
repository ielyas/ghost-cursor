// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GhostCursorKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GhostCursorKit", targets: ["GhostCursorKit"])
    ],
    targets: [
        .target(name: "GhostCursorKit"),
        .testTarget(name: "GhostCursorKitTests", dependencies: ["GhostCursorKit"])
    ]
)

// swift-tools-version: 6.0
import PackageDescription

/// NOIR LEDGER's deterministic game core: content, economy, simulation, campaign and save format.
/// It has no UI and no platform-clock dependency, so it is fully testable with `swift test` on a Mac host.
let package = Package(
    name: "NoirCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NoirCore", targets: ["NoirCore"]),
    ],
    targets: [
        .target(name: "NoirCore"),
        .testTarget(name: "NoirCoreTests", dependencies: ["NoirCore"]),
    ]
)

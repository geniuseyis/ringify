// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RingifyCore",
    products: [
        .library(name: "RingifyCore", targets: ["RingifyCore"])
    ],
    targets: [
        .target(name: "RingifyCore"),
        .testTarget(name: "RingifyCoreTests", dependencies: ["RingifyCore"], resources: [.process("Fixtures")])
    ]
)

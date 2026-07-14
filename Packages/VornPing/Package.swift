// swift-tools-version: 6.0
import PackageDescription

// Измерение задержки до сервера по времени TCP-хендшейка (Network framework).
let package = Package(
    name: "VornPing",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "VornPing", targets: ["VornPing"]),
    ],
    targets: [
        .target(name: "VornPing", path: "Sources"),
        .testTarget(name: "VornPingTests", dependencies: ["VornPing"], path: "Tests/VornPingTests"),
    ]
)

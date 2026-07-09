// swift-tools-version: 6.0
import PackageDescription

// Хранение: Keychain (access group) и обмен конфигом с extension через App Group.
let package = Package(
    name: "VornStorage",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "VornStorage", targets: ["VornStorage"]),
    ],
    dependencies: [
        .package(path: "../VornCore"),
    ],
    targets: [
        .target(name: "VornStorage", dependencies: ["VornCore"], path: "Sources"),
        .testTarget(name: "VornStorageTests", dependencies: ["VornStorage"], path: "Tests/VornStorageTests"),
    ]
)

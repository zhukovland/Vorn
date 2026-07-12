// swift-tools-version: 6.0
import PackageDescription

// Загрузка подписок: HTTP-выборка подписочного URL и разбор ответа
// (тело — через VornCore.SubscriptionParser, заголовки — здесь).
let package = Package(
    name: "VornSubscription",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "VornSubscription", targets: ["VornSubscription"]),
    ],
    dependencies: [
        .package(path: "../VornCore"),
    ],
    targets: [
        .target(name: "VornSubscription", dependencies: ["VornCore"], path: "Sources"),
        .testTarget(
            name: "VornSubscriptionTests",
            dependencies: ["VornSubscription"],
            path: "Tests/VornSubscriptionTests"
        ),
    ]
)

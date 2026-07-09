// swift-tools-version: 6.0
import PackageDescription

// Платформенно-нейтральное ядро: модели, парсинг подписок, генерация конфига.
// Никаких зависимостей от UI, NetworkExtension и SwiftyXrayKit.
let package = Package(
    name: "VornCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "VornCore", targets: ["VornCore"]),
    ],
    targets: [
        .target(name: "VornCore", path: "Sources"),
        .testTarget(name: "VornCoreTests", dependencies: ["VornCore"], path: "Tests/VornCoreTests"),
    ]
)

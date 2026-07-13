// swift-tools-version: 6.0
import PackageDescription

// Дизайн-система: токены (цвет/тип/отступы/движение), две темы и
// переиспользуемые компоненты. Домен не знает — принимает примитивы.
let package = Package(
    name: "VornDesignSystem",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "VornDesignSystem", targets: ["VornDesignSystem"]),
    ],
    targets: [
        .target(name: "VornDesignSystem", path: "Sources"),
        .testTarget(
            name: "VornDesignSystemTests",
            dependencies: ["VornDesignSystem"],
            path: "Tests/VornDesignSystemTests"
        ),
    ]
)

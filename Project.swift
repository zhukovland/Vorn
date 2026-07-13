import ProjectDescription

let teamID = "GRFP8RCXX9"

// iOS 17 / macOS 14: приложение использует Observation (@Observable).
let deployment: DeploymentTargets = .multiplatform(iOS: "17.0", macOS: "14.0")

let project = Project(
    name: "Vorn",
    organizationName: "bigboys",
    packages: [
        .package(path: "Packages/VornCore"),
        .package(path: "Packages/VornStorage"),
        .package(path: "Packages/VornSubscription"),
        .package(path: "Packages/VornDesignSystem"),
        // Только для таргета PacketTunnel — см. правило изоляции в CLAUDE.md.
        // Пин .exact: компонент видит весь расшифрованный трафик, поэтому
        // версию поднимаем осознанно после ревью, а не авто-обновлением тега.
        .remote(
            url: "https://github.com/dima-u/SwiftyXrayKit.git",
            requirement: .exact("2.0.0")
        ),
    ],
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": .string(teamID),
            "CODE_SIGN_STYLE": "Automatic",
            "SWIFT_VERSION": "6.0",
            "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
            "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
        ]
    ),
    targets: [
        .target(
            name: "Vorn",
            destinations: [.iPhone, .iPad, .mac],
            product: .app,
            bundleId: "com.bigboys.Vorn",
            deploymentTargets: deployment,
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight",
                ],
            ]),
            sources: ["App/Sources/**"],
            resources: ["App/Resources/**"],
            dependencies: [
                .package(product: "VornCore"),
                .package(product: "VornStorage"),
                .package(product: "VornSubscription"),
                .package(product: "VornDesignSystem"),
                .target(name: "PacketTunnel"),
            ],
            settings: .settings(base: [
                "CODE_SIGN_ENTITLEMENTS": "App/Vorn-iOS.entitlements",
                "CODE_SIGN_ENTITLEMENTS[sdk=macosx*]": "App/Vorn-macOS.entitlements",
            ])
        ),
        .target(
            name: "PacketTunnel",
            destinations: [.iPhone, .iPad, .mac],
            product: .appExtension,
            bundleId: "com.bigboys.Vorn.PacketTunnel",
            deploymentTargets: deployment,
            infoPlist: .extendingDefault(with: [
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.networkextension.packet-tunnel",
                    "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).PacketTunnelProvider",
                ],
            ]),
            sources: ["PacketTunnel/Sources/**"],
            dependencies: [
                .package(product: "VornCore"),
                .package(product: "VornStorage"),
                .package(product: "SwiftyXrayKit"),
            ],
            settings: .settings(base: [
                // Extension — фоновый процесс: nonisolated-дефолт, как в пакетах.
                "SWIFT_DEFAULT_ACTOR_ISOLATION": "nonisolated",
                "CODE_SIGN_ENTITLEMENTS": "PacketTunnel/PacketTunnel-iOS.entitlements",
                "CODE_SIGN_ENTITLEMENTS[sdk=macosx*]": "PacketTunnel/PacketTunnel-macOS.entitlements",
            ])
        ),
    ]
)

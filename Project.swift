import ProjectDescription

let teamID = "GRFP8RCXX9"

let project = Project(
    name: "Vorn",
    organizationName: "bigboys",
    packages: [
        .package(path: "Packages/VornCore"),
        .package(path: "Packages/VornStorage"),
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
            deploymentTargets: .multiplatform(iOS: "15.0", macOS: "13.0"),
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
            ]
        ),
    ]
)

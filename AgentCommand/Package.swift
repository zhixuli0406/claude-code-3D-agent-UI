// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentCommand",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AgentCommand",
            path: "AgentCommand",
            exclude: ["Resources/Assets.xcassets"],
            resources: [
                .copy("Resources/SampleConfigs")
            ]
        ),
        .testTarget(
            name: "AgentCommandTests",
            dependencies: ["AgentCommand"],
            path: "Tests"
        )
    ]
)

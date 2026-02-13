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
            exclude: ["Resources/Logo"],
            resources: [
                .copy("Resources/SampleConfigs"),
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "AgentCommandTests",
            dependencies: ["AgentCommand"],
            path: "Tests"
        )
    ]
)

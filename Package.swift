// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MDVisualizer",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MDVisualizer",
            path: "Sources/MDVisualizer",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)

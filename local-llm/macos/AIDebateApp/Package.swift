// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIDebateApp",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AIDebateApp",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("AIDebateApp/Resources")
            ]
        )
    ]
)

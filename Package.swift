// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Quarantine",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Quarantine",
            path: "Sources/Quarantine",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

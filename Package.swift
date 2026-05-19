// swift-tools-version: 5.9
import PackageDescription

// Quarantine: `QuarantinePane` (downloads inspector as a dynamic
// library via SuiteKit, loadable by the launcher; bundles its PNG
// glyphs) + `Quarantine` (thin @main standalone shim).
let package = Package(
    name: "Quarantine",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Quarantine", targets: ["Quarantine"]),
        .library(name: "QuarantinePane", type: .dynamic, targets: ["QuarantinePane"])
    ],
    dependencies: [ .package(path: "../suitekit-swift") ],
    targets: [
        .target(
            name: "QuarantinePane",
            dependencies: [.product(name: "SuiteKit", package: "suitekit-swift")],
            path: "Sources/QuarantinePane",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Quarantine",
            dependencies: ["QuarantinePane", .product(name: "SuiteKit", package: "suitekit-swift")],
            path: "Sources/Quarantine"
        )
    ]
)

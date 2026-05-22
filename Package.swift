// swift-tools-version: 5.9
import PackageDescription

// Quarantine: three SPM products —
//   • `QuarantinePane` (.dynamic) — downloads inspector dylib.
//   • `Quarantine` (.executable) — thin standalone shim.
//   • `QuarantineShared` (.library, .static) — App Group +
//     `SharedQuarantine` snapshot model + `SharedQuarantineStore` +
//     `RescanIntent` / `IntentBus`. Consumed by `QuarantinePane`,
//     `Quarantine`, AND the Xcode widget target at
//     `Widget/QuarantineWidgets.xcodeproj`. SwiftPM can't build the
//     widget extension itself (SR-14944: no app-extension productType).
let package = Package(
    name: "Quarantine",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Quarantine", targets: ["Quarantine"]),
        .library(name: "QuarantinePane", type: .dynamic,
                 targets: ["QuarantinePane"]),
        .library(name: "QuarantineShared",
                 targets: ["QuarantineShared"])
    ],
    dependencies: [ .package(path: "../suitekit-swift") ],
    targets: [
        .target(
            name: "QuarantineShared",
            path: "Sources/QuarantineShared"
        ),
        .target(
            name: "QuarantinePane",
            dependencies: [
                "QuarantineShared",
                .product(name: "SuiteKit", package: "suitekit-swift")
            ],
            path: "Sources/QuarantinePane",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Quarantine",
            dependencies: [
                "QuarantinePane",
                "QuarantineShared",
                .product(name: "SuiteKit", package: "suitekit-swift")
            ],
            path: "Sources/Quarantine"
        )
    ]
)

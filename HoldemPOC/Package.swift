// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HoldemPOC",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "HoldemPOC", targets: ["HoldemPOCApp"]),
    ],
    targets: [
        .target(
            name: "CPokerCore",
            path: "Sources/CPokerCore",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "HoldemPOCApp",
            dependencies: ["CPokerCore"],
            path: "Sources/HoldemPOCApp",
            linkerSettings: [
                .unsafeFlags(["-L../poker_core/target/release", "-lpoker_core"]),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("ScreenCaptureKit"),
            ]
        ),
    ]
)

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Consta",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "Consta", targets: ["Consta"]),
        .library(name: "ConstaKit", targets: ["ConstaKit"]),
    ],
    targets: [
        // Pure game logic (XP, levels, goals, streaks, badges). No UI or persistence.
        .target(name: "ConstaKit"),
        // The menu bar app: SwiftUI + SwiftData.
        .executableTarget(name: "Consta", dependencies: ["ConstaKit"]),
        .testTarget(name: "ConstaKitTests", dependencies: ["ConstaKit"]),
    ]
)

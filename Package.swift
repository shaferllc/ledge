// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ledge",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Ledge",
            path: "Sources/Ledge"
        ),
        // Tiny companion CLI: `ledge notify/progress/timer …` pushes ambient
        // status into the running app's notch via a distributed notification.
        // Target name differs from "Ledge" by more than case: on the
        // case-insensitive macOS filesystem a target named "ledge" would share
        // "Ledge"'s *.build intermediate dir and fail to link. The built binary
        // is installed/distributed as `ledge`.
        .executableTarget(
            name: "LedgeCLI",
            path: "Sources/LedgeCLI"
        ),
        .testTarget(
            name: "LedgeTests",
            dependencies: ["Ledge"],
            path: "Tests/LedgeTests"
        ),
    ]
)

// swift-tools-version:6.2
import PackageDescription

// Swift 6 language mode, main-actor-by-default (AppKit app: timers, hotkey and cursor calls live on the main thread).
let app: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Poof",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PoofKit", path: "Sources/PoofKit", swiftSettings: app),
        .executableTarget(name: "Poof", dependencies: ["PoofKit"], path: "Sources/Poof", swiftSettings: app),
        .testTarget(name: "PoofTests", dependencies: ["PoofKit"], path: "Tests/PoofTests", swiftSettings: app),
    ]
)

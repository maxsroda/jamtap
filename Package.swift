// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JamTap",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic with no AppKit, so it is unit-tested.
        .target(name: "JamTapCore"),
        // The menu bar app: a thin AppKit shell around JamTapCore.
        .executableTarget(
            name: "JamTap",
            dependencies: ["JamTapCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "JamTapCoreTests", dependencies: ["JamTapCore"]),
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceInk",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "VoiceInk",
            path: "Sources/VoiceInk",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("Cocoa"),
            ]
        )
    ]
)

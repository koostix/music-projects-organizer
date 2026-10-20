// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MusicProjectsOrganizer",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MusicProjectsOrganizerCore", targets: ["MusicProjectsOrganizerCore"]),
    ],
    targets: [
        .target(name: "MusicProjectsOrganizerCore"),
        .testTarget(name: "MusicProjectsOrganizerCoreTests", dependencies: ["MusicProjectsOrganizerCore"]),
    ],
    swiftLanguageModes: [.v5]
)

// The app target links SwiftUI, AppKit, and AVFoundation, which exist only on macOS.
#if os(macOS)
package.products += [
    .executable(name: "MusicProjectsOrganizer", targets: ["App"]),
]
package.targets += [
    .executableTarget(
        name: "App",
        dependencies: ["MusicProjectsOrganizerCore"],
        path: "Sources/App",
        exclude: ["Info.plist"]
    ),
]
#endif

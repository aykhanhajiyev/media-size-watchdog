// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MediaSizeWatchdog",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "MediaSizeWatchdog",
            targets: ["MediaSizeWatchdog"]
        )
    ],
    targets: [
        .target(
            name: "MediaSizeWatchdog"
        ),
        .testTarget(
            name: "MediaSizeWatchdogTests",
            dependencies: ["MediaSizeWatchdog"]
        )
    ]
)

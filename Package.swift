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
        ),
        .library(
            name: "MediaSizeWatchdogAlamofire",
            targets: ["MediaSizeWatchdogAlamofire"]
        ),
        .library(
            name: "MediaSizeWatchdogSDWebImage",
            targets: ["MediaSizeWatchdogSDWebImage"]
        ),
        .library(
            name: "MediaSizeWatchdogKingfisher",
            targets: ["MediaSizeWatchdogKingfisher"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.0.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.3.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "MediaSizeWatchdog"
        ),
        .target(
            name: "MediaSizeWatchdogAlamofire",
            dependencies: [
                "MediaSizeWatchdog",
                .product(name: "Alamofire", package: "Alamofire")
            ]
        ),
        .target(
            name: "MediaSizeWatchdogSDWebImage",
            dependencies: [
                "MediaSizeWatchdog",
                .product(name: "SDWebImage", package: "SDWebImage")
            ]
        ),
        .target(
            name: "MediaSizeWatchdogKingfisher",
            dependencies: [
                "MediaSizeWatchdog",
                .product(name: "Kingfisher", package: "Kingfisher")
            ]
        ),
        .testTarget(
            name: "MediaSizeWatchdogTests",
            dependencies: ["MediaSizeWatchdog"]
        )
    ]
)

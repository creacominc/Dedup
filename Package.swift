// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Dedup",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "Dedup",
            targets: ["Dedup"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Dedup",
            path: "Dedup",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "Dedup.entitlements"
            ]
        ),
        .testTarget(
            name: "DedupTests",
            dependencies: ["Dedup"],
            path: "DedupTests"
        ),
        .testTarget(
            name: "DedupUITests",
            dependencies: ["Dedup"],
            path: "DedupUITests"
        )
    ]
) 
// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuickScanPro",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "QuickScanPro",
            targets: ["QuickScanPro"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.6.0")
    ],
    targets: [
        .target(
            name: "QuickScanPro",
            dependencies: ["SnapKit"],
            path: "Sources"),
        .testTarget(
            name: "QuickScanProTests",
            dependencies: ["QuickScanPro"]),
    ]
)
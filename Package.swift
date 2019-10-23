// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "URLImageView",
    platforms: [.iOS(.v10)],
    products: [
        .library(
            name: "URLImageView",
            targets: ["URLImageView"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "URLImageView",
            dependencies: []),
    ]
)

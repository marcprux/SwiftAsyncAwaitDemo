// swift-tools-version:5.3

import PackageDescription

// NOTE: Requires Swift 5.5+
let package = Package(
    name: "SwiftAsyncAwaitDemo",
    products: [
        .library(
            name: "SwiftAsyncAwaitDemo",
            targets: ["SwiftAsyncAwaitDemo"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftAsyncAwaitDemo",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags([
                    "-Xfrontend",
                    "-enable-experimental-concurrency"
                ])
            ]
        ),
        .testTarget(
            name: "SwiftAsyncAwaitDemoTests",
            dependencies: ["SwiftAsyncAwaitDemo"],
            swiftSettings: [
                .unsafeFlags([
                    "-Xfrontend",
                    "-enable-experimental-concurrency"
                ])
            ]
        ),
    ],
    swiftLanguageVersions: [
        .version("5.5")
    ]
)

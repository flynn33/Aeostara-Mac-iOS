// swift-tools-version: 5.9
// Copyright (c) 2026 James Daley. All Rights Reserved.

import PackageDescription

let package = Package(
    name: "Aeostara",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AeostaraMacCLI", targets: ["AeostaraMacCLI"]),
        .library(name: "AeostaraMacDomain", targets: ["AeostaraMacDomain"]),
        .library(name: "AeostaraMacServices", targets: ["AeostaraMacServices"])
    ],
    targets: [
        .target(
            name: "AeostaraMacDomain",
            path: "Sources/AeostaraMacDomain"
        ),
        .target(
            name: "AeostaraMacServices",
            dependencies: ["AeostaraMacDomain"],
            path: "Sources/AeostaraMacServices"
        ),
        .executableTarget(
            name: "AeostaraMacCLI",
            dependencies: ["AeostaraMacDomain", "AeostaraMacServices"],
            path: "Sources/AeostaraMacCLI"
        ),
        .testTarget(
            name: "AeostaraMacTests",
            dependencies: ["AeostaraMacDomain", "AeostaraMacServices"],
            path: "Tests/AeostaraMacTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)

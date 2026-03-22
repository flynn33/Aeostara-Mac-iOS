// swift-tools-version: 5.9
// Copyright (c) 2026 James Daley. All Rights Reserved.

import PackageDescription

let package = Package(
    name: "Aeostara",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "AeostaraDomain", targets: ["AeostaraDomain"]),
        .library(name: "AeostaraServices", targets: ["AeostaraServices"])
    ],
    targets: [
        .target(
            name: "AeostaraDomain",
            path: "Sources/AeostaraDomain"
        ),
        .target(
            name: "AeostaraServices",
            dependencies: ["AeostaraDomain"],
            path: "Sources/AeostaraServices"
        ),
        .testTarget(
            name: "AeostaraTests",
            dependencies: ["AeostaraDomain", "AeostaraServices"],
            path: "Tests/AeostaraTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)

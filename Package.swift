// swift-tools-version: 5.9
// Copyright 2026 James Daley, DBA: Raven Forge Software. See LICENSE for license terms.

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
        .target(
            name: "AeostaraDevelopmentDiagnostics",
            dependencies: ["AeostaraDomain"],
            path: "Sources/AeostaraDevelopmentDiagnostics"
        ),
        .testTarget(
            name: "AeostaraTests",
            dependencies: ["AeostaraDomain", "AeostaraServices", "AeostaraDevelopmentDiagnostics"],
            path: "Tests/AeostaraTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)

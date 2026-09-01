// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "NexusFeatures",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SharedUI", targets: ["SharedUI"]),
        .library(name: "Navigation", targets: ["Navigation"]),
        .library(name: "Dashboard", targets: ["Dashboard"]),
        .library(name: "CardDetail", targets: ["CardDetail"]),
    ],
    dependencies: [
        .package(path: "../NexusDomain"),
        .package(path: "../NexusData"),
    ],
    targets: [
        .target(name: "SharedUI"),
        .target(name: "Navigation"),
        .target(
            name: "Dashboard",
            dependencies: [
                "Navigation",
                "SharedUI",
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "Mocks", package: "NexusData"),
                .product(name: "RepositoryProtocols", package: "NexusDomain"),
            ]
        ),
        .target(
            name: "CardDetail",
            dependencies: [
                "Navigation",
                "SharedUI",
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "Mocks", package: "NexusData"),
                .product(name: "RepositoryProtocols", package: "NexusDomain"),
            ]
        ),
        .testTarget(
            name: "NexusFeaturesTests",
            dependencies: ["CardDetail", "Dashboard", "Navigation", "SharedUI"]
        ),
    ]
)

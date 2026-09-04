// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "NexusFeatures",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "Design", targets: ["Design"]),
        .library(name: "SharedUI", targets: ["SharedUI"]),
        .library(name: "Navigation", targets: ["Navigation"]),
        .library(name: "Dashboard", targets: ["Dashboard"]),
        .library(name: "CardDetail", targets: ["CardDetail"]),
        .library(name: "Transactions", targets: ["Transactions"]),
    ],
    dependencies: [
        .package(path: "../NexusDomain"),
        .package(path: "../NexusData"),
    ],
    targets: [
        // Design tokens (colors, spacing, icons, copy) live in their own
        // target so any UI consumer can adopt them without pulling in
        // components. Depends on nothing but the platform SDKs — the single
        // place platform-resolved values live.
        .target(name: "Design"),
        .target(
            name: "SharedUI",
            dependencies: [
                "Design",
                .product(name: "Entities", package: "NexusDomain"),
            ],
        ),
        .target(name: "Navigation"),
        .target(
            name: "Dashboard",
            dependencies: [
                "Navigation",
                "SharedUI",
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "Mocks", package: "NexusData"),
                .product(name: "RepositoryProtocols", package: "NexusDomain"),
            ],
        ),
        .target(
            name: "CardDetail",
            dependencies: [
                "Navigation",
                "SharedUI",
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "Mocks", package: "NexusData"),
                .product(name: "RepositoryProtocols", package: "NexusDomain"),
            ],
        ),
        // Per-card account activity: balance header and the transaction
        // history + details screens.
        .target(
            name: "Transactions",
            dependencies: [
                "Design",
                "Navigation",
                "SharedUI",
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "Mocks", package: "NexusData"),
                .product(name: "RepositoryProtocols", package: "NexusDomain"),
            ],
        ),
        .testTarget(
            name: "NexusFeaturesTests",
            dependencies: [
                "CardDetail",
                "Dashboard",
                "Navigation",
                "SharedUI",
                "Transactions",
                // Mock repositories power the model tests' loading/error
                // knobs and call counts.
                .product(name: "Mocks", package: "NexusData"),
            ],
        ),
    ],
)

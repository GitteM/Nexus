// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "NexusData",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Session", targets: ["Session"]),
        .library(name: "DataSources", targets: ["DataSources"]),
        .library(name: "Repositories", targets: ["Repositories"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "Logging", targets: ["Logging"]),
        .library(name: "Mocks", targets: ["Mocks"]),
    ],
    dependencies: [
        .package(path: "../NexusDomain"),
    ],
    targets: [
        .target(
            name: "Session",
            dependencies: [
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "ServiceProtocols", package: "NexusDomain"),
            ],
        ),
        .target(
            name: "DataSources",
            dependencies: [
                "Session",
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "ServiceProtocols", package: "NexusDomain"),
            ],
        ),
        .target(
            name: "Repositories",
            dependencies: [
                "DataSources",
                "Persistence",
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "RepositoryProtocols", package: "NexusDomain"),
            ],
        ),
        .target(
            name: "Persistence",
            dependencies: [
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "RepositoryProtocols", package: "NexusDomain"),
            ],
        ),
        .target(
            name: "Logging",
            dependencies: [
                .product(name: "ServiceProtocols", package: "NexusDomain"),
            ],
        ),
        .target(
            name: "Mocks",
            dependencies: [
                "DataSources",
                "Logging",
                "Persistence",
                "Repositories",
                "Session",
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "RepositoryProtocols", package: "NexusDomain"),
                .product(name: "ServiceProtocols", package: "NexusDomain"),
            ],
        ),
        .testTarget(
            name: "NexusDataTests",
            dependencies: [
                "DataSources",
                "Logging",
                "Mocks",
                "Persistence",
                "Repositories",
                "Session",
                // Declared explicitly for the Xcode workspace build: the
                // dependency scan of the test target follows `Session`'s own
                // imports (Entities/ServiceProtocols) and warns when those
                // edges are missing from the generated project.
                .product(name: "Entities", package: "NexusDomain"),
                .product(name: "ServiceProtocols", package: "NexusDomain"),
            ],
        ),
    ],
)

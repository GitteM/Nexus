// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "NexusDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Entities", targets: ["Entities"]),
        .library(name: "RepositoryProtocols", targets: ["RepositoryProtocols"]),
        .library(name: "ServiceProtocols", targets: ["ServiceProtocols"]),
    ],
    targets: [
        .target(name: "Entities"),
        .target(name: "RepositoryProtocols", dependencies: ["Entities"]),
        .target(name: "ServiceProtocols", dependencies: ["Entities"]),
        .testTarget(
            name: "NexusDomainTests",
            dependencies: ["Entities", "RepositoryProtocols", "ServiceProtocols"]
        ),
    ]
)

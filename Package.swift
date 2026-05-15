// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "auralogs-swift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "Auralogs", targets: ["Auralogs"]),
        .library(name: "AuralogsSwiftLog", targets: ["AuralogsSwiftLog"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "Auralogs",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "AuralogsSwiftLog",
            dependencies: [
                "Auralogs",
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "AuralogsTests",
            dependencies: ["Auralogs"]
        )
    ]
)

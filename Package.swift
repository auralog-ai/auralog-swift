// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "auralog-swift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "Auralog", targets: ["Auralog"]),
        .library(name: "AuralogSwiftLog", targets: ["AuralogSwiftLog"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "Auralog",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "AuralogSwiftLog",
            dependencies: [
                "Auralog",
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "AuralogTests",
            dependencies: ["Auralog"]
        )
    ]
)

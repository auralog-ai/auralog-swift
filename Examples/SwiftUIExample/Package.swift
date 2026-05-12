// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AuralogSwiftUIExample",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "AuralogSwiftUIExample", targets: ["AuralogSwiftUIExample"])
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "AuralogSwiftUIExample",
            dependencies: [
                .product(name: "Auralog", package: "auralog-swift"),
                .product(name: "AuralogSwiftLog", package: "auralog-swift")
            ]
        )
    ]
)

// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AuralogsSwiftUIExample",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "AuralogsSwiftUIExample", targets: ["AuralogsSwiftUIExample"])
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "AuralogsSwiftUIExample",
            dependencies: [
                .product(name: "Auralogs", package: "auralogs-swift"),
                .product(name: "AuralogsSwiftLog", package: "auralogs-swift")
            ]
        )
    ]
)

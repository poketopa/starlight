// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Starlight",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Starlight", targets: ["Starlight"])
    ],
    targets: [
        .executableTarget(
            name: "Starlight",
            path: "Sources/Starlight"
        ),
        .testTarget(
            name: "StarlightTests",
            dependencies: ["Starlight"],
            path: "Tests/StarlightTests"
        )
    ]
)


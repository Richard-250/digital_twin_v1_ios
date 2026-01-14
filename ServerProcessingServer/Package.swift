// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ServerProcessingServer",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ServerProcessingServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ]
        ),
    ]
)


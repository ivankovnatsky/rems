// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "rems",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "rems", targets: ["rems"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.3.1")),
    ],
    targets: [
        .executableTarget(
            name: "rems",
            dependencies: ["RemsLibrary"]
        ),
        .target(
            name: "RemsLibrary",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "RemsTests",
            dependencies: ["RemsLibrary"]
        ),
    ]
)

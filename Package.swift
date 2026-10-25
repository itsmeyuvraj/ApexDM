// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ApexDM",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ApexDM",
            targets: ["ApexDM"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ApexDM",
            path: "Sources/ApexDM"
        ),
        .testTarget(
            name: "ApexDMTests",
            dependencies: ["ApexDM"],
            path: "Tests/ApexDMTests"
        )
    ]
)

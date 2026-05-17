// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StatusOrbit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "StatusOrbit", targets: ["StatusOrbit"])
    ],
    targets: [
        .executableTarget(
            name: "StatusOrbit",
            path: "Sources/StatusOrbit",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)

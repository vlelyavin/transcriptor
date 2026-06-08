// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Sotto",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Sotto", targets: ["Sotto"]),
        .library(name: "SottoKit", targets: ["SottoKit"]),
    ],
    targets: [
        .executableTarget(
            name: "Sotto",
            dependencies: ["SottoKit"]
        ),
        .executableTarget(
            name: "SottoSmokeChecks",
            dependencies: ["SottoKit"]
        ),
        .target(
            name: "SottoKit"
        ),
        .testTarget(
            name: "SottoKitTests",
            dependencies: ["SottoKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

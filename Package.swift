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
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.0.0"),
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
            name: "SottoKit",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ]
        ),
        .testTarget(
            name: "SottoKitTests",
            dependencies: ["SottoKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Transcriptor",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Transcriptor", targets: ["Transcriptor"]),
        .library(name: "TranscriptorKit", targets: ["TranscriptorKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Transcriptor",
            dependencies: ["TranscriptorKit"]
        ),
        .executableTarget(
            name: "TranscriptorSmokeChecks",
            dependencies: ["TranscriptorKit"]
        ),
        .target(
            name: "TranscriptorKit",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ]
        ),
        .testTarget(
            name: "TranscriptorKitTests",
            dependencies: ["TranscriptorKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

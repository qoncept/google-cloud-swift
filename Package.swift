// swift-tools-version:5.8
import PackageDescription

func swiftSettings(strictConcurrency: Bool = true) -> [SwiftSetting] {
    var settings: [SwiftSetting] = [
        .enableUpcomingFeature("ForwardTrailingClosures"),
        .enableUpcomingFeature("ConciseMagicFile"),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
        .enableUpcomingFeature("ExistentialAny")
    ]

    if strictConcurrency {
        settings.append(
            .unsafeFlags(["-strict-concurrency=complete"])
        )
    }

    return settings
}

let package = Package(
    name: "google-cloud-swift",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FirebaseAdmin", targets: ["FirebaseAdmin"]),
        .library(name: "GoogleCloud", targets: ["GoogleCloud"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.1.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.18.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.13.0"),
    ],
    targets: [
        .target(
            name: "GoogleCloudBase",
            dependencies: [
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "JWTKit", package: "jwt-kit"),
            ],
            swiftSettings: swiftSettings()
        ),
        .target(
            name: "GoogleCloud",
            dependencies: [
                "GoogleCloudBase",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: swiftSettings()
        ),
        .target(
            name: "FirebaseAdmin",
            dependencies: [
                "GoogleCloudBase",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "JWTKit", package: "jwt-kit"),
            ],
            swiftSettings: swiftSettings()
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: [
                "GoogleCloud",
                "FirebaseAdmin",
            ],
            swiftSettings: swiftSettings(strictConcurrency: false)
        ),
    ]
)

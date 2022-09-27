// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "google-cloud-swift",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "FirebaseAdmin", targets: ["FirebaseAdmin"]),
        .library(name: "GoogleCloud", targets: ["GoogleCloud"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.1.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.11.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.7.0"),
    ],
    targets: [
        .target(
            name: "GoogleCloudBase",
            dependencies: [
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "JWTKit", package: "jwt-kit"),
            ],
            swiftSettings: [
                .unsafeFlags(["-warn-concurrency"]),
            ]
        ),
        .target(
            name: "GoogleCloud",
            dependencies: [
                "GoogleCloudBase",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: [
                .unsafeFlags(["-warn-concurrency"]),
            ]
        ),
        .target(
            name: "FirebaseAdmin",
            dependencies: [
                "GoogleCloudBase",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "JWTKit", package: "jwt-kit"),
            ],
            swiftSettings: [
                .unsafeFlags(["-warn-concurrency"]),
            ]
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: [
                "GoogleCloud",
                "FirebaseAdmin",
            ]
        ),
    ]
)

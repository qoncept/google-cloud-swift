// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "google-cloud-swift",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FirebaseAdmin", targets: ["FirebaseAdmin"]),
        .library(name: "GoogleCloud", targets: ["GoogleCloud"]),
    ],
    traits: [
        "ServiceLifecycleSupport",
        .default(
            enabledTraits: [
                "ServiceLifecycleSupport"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "5.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.30.2"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.1.1"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.9.1"),
    ],
    targets: [
        .target(
            name: "GoogleCloudBase",
            dependencies: [
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(
                    name: "ServiceLifecycle",
                    package: "swift-service-lifecycle",
                    condition: .when(traits: ["ServiceLifecycleSupport"])
                ),
            ]
        ),
        .target(
            name: "GoogleCloud",
            dependencies: [
                "GoogleCloudBase",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        .target(
            name: "FirebaseAdmin",
            dependencies: [
                "GoogleCloudBase",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "JWTKit", package: "jwt-kit"),
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

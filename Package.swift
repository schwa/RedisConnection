// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RedisConnection",
    platforms: [
        .iOS("16.0"),
        .macOS("13.0"),
        .macCatalyst("16.0")
    ],
    products: [
        .library(name: "RedisConnection", targets: ["RedisConnection"])
    ],
    targets: [
        .executableTarget(
            name: "CLI",
            dependencies: ["RedisConnection"],
            swiftSettings: [.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])]
        ),
        .target(
            name: "RedisConnection",
            swiftSettings: [.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])]
        ),
        .testTarget(
            name: "RedisConnectionTests",
            dependencies: ["RedisConnection"],
            resources: [.copy("foo.dat")]
        )
    ]
)

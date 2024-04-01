// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RedisConnection",
    platforms: [
        .iOS("17.0"),
        .macOS("14.0"),
        .macCatalyst("17.0")
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

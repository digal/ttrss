// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "ttrss",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0"),
        .package(url: "https://github.com/BrettRToomey/Jobs.git", from: "1.1.2"),
        .package(url: "https://github.com/nmdias/FeedKit.git", from: "8.0.0")
    ],
    targets: [
        .target(name: "App", dependencies: ["FluentPostgreSQL", "Vapor", "Jobs", "FeedKit"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)


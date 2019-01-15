// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "ttrss",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0"),
        .package(url: "https://github.com/BrettRToomey/Jobs.git", from: "1.1.2"),
        .package(url: "https://github.com/nmdias/FeedKit.git", .revision("4a7b7a9a43f90c02873440209362094a3ec0c63e"))
    ],
    targets: [
        .target(name: "App", dependencies: ["FluentPostgreSQL", "Vapor", "Jobs", "FeedKit"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)


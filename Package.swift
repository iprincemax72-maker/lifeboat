// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Lifeboat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Lifeboat"),
        .testTarget(name: "LifeboatTests", dependencies: ["Lifeboat"]),
    ]
)

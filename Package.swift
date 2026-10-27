// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Keypress",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Keypress", targets: ["Keypress"])],
    targets: [
        .target(name: "KeypressCore"),
        .executableTarget(name: "Keypress", dependencies: ["KeypressCore"]),
        .testTarget(name: "KeypressCoreTests", dependencies: ["KeypressCore"])
    ],
    swiftLanguageModes: [.v5]
)

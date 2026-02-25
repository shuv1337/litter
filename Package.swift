// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Shitter",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "Shitter", targets: ["Shitter"])
    ],
    targets: [
        .binaryTarget(
            name: "codex_bridge",
            path: "apps/ios/Frameworks/codex_bridge.xcframework"
        ),
        .target(
            name: "Shitter",
            dependencies: ["codex_bridge"],
            path: "apps/ios/Sources/Shitter",
            publicHeadersPath: "Bridge"
        )
    ]
)

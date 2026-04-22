// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickPolish2",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "QuickPolish2",
            dependencies: ["QuickPolish2Core"],
            path: "Sources/QuickPolish2"
        ),
        .target(
            name: "QuickPolish2Core",
            path: "Sources/QuickPolish2Core"
        ),
        .testTarget(
            name: "QuickPolish2Tests",
            dependencies: ["QuickPolish2Core"],
            path: "Tests/QuickPolish2Tests"
        )
    ]
)

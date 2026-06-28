// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CursorTimeline",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CursorTimeline", targets: ["CursorTimeline"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "CursorTimelineCore",
            path: "Sources/CursorTimeline/Core"
        ),
        .executableTarget(
            name: "CursorTimeline",
            dependencies: [
                "CursorTimelineCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/CursorTimeline/App"
        ),
        .testTarget(
            name: "CursorTimelineTests",
            dependencies: ["CursorTimelineCore"],
            path: "Tests/CursorTimelineTests"
        ),
    ]
)

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
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/CursorTimeline/Core"
        ),
        .target(
            name: "CursorTimelineUI",
            dependencies: ["CursorTimelineCore"],
            path: "Sources/CursorTimeline/Features"
        ),
        .executableTarget(
            name: "CursorTimeline",
            dependencies: [
                "CursorTimelineCore",
                "CursorTimelineUI",
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

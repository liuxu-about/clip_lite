// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClipLite",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "ClipLite", targets: ["ClipLite"]),
    ],
    targets: [
        .executableTarget(
            name: "ClipLite",
            path: "ClipLite",
            exclude: [
                "Resources",
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "ClipLiteTests",
            dependencies: ["ClipLite"],
            path: "Tests/ClipLiteTests"
        ),
    ]
)

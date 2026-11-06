// swift-tools-version:5.9
// Test harness for the Baroque parsers. The source target is made of symlinks to
// ../Shared so the tests always exercise the exact files the app and widget ship.
// Run with: cd ParserTests && swift test
import PackageDescription

let package = Package(
    name: "BaroqueParserTests",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "BaroqueCore",
            path: "Sources/BaroqueCore"
        ),
        .testTarget(
            name: "BaroqueCoreTests",
            dependencies: ["BaroqueCore"],
            path: "Tests/BaroqueCoreTests"
        )
    ]
)

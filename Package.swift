// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Reminder2Cal",

    // Minimum platform versions
    platforms: [
        .macOS(.v14)
    ],

    // Products define the executables and libraries this package produces
    products: [
        .executable(
            name: "Reminder2Cal",
            targets: ["Reminder2Cal"]
        ),
        .library(
            name: "Reminder2CalCore",
            targets: ["Reminder2CalCore"]
        )
    ],

    // Dependencies declare other packages that this package depends on
    dependencies: [
        // Add external dependencies here when needed
        // .package(url: "https://github.com/example/example.git", from: "1.0.0"),
    ],

    // Targets are the basic building blocks of a package
    targets: [
        // Core framework - Business logic and services
        .target(
            name: "Reminder2CalCore",
            dependencies: [],
            path: "Sources/Reminder2CalCore"
        ),

        // Main executable target - UI and app logic
        .executableTarget(
            name: "Reminder2Cal",
            dependencies: [
                "Reminder2CalCore"
            ],
            path: "Sources/Reminder2Cal"
        ),
        
        // Test targets
        .testTarget(
            name: "Reminder2CalCoreTests",
            dependencies: ["Reminder2CalCore"],
            path: "Tests/Reminder2CalCoreTests"
        ),
        .testTarget(
            name: "Reminder2CalTests",
            dependencies: ["Reminder2Cal", "Reminder2CalCore"],
            path: "Tests/Reminder2CalTests"
        )
    ],

    // Swift language version
    swiftLanguageVersions: [.v5]
)
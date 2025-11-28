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
    ],

    // Dependencies declare other packages that this package depends on
    dependencies: [
        // Add external dependencies here when needed
        // .package(url: "https://github.com/example/example.git", from: "1.0.0"),
    ],

    // Targets are the basic building blocks of a package
    targets: [
        // AppConfig module - Handles application configuration
        .target(
            name: "AppConfig",
            dependencies: [],
            path: "Sources/AppConfig"
        ),

        // Reminder2CalSync module - Core sync logic
        .target(
            name: "Reminder2CalSync",
            dependencies: ["AppConfig"],
            path: "Sources/Reminder2CalSync"
        ),

        // Main executable target
        .executableTarget(
            name: "Reminder2Cal",
            dependencies: [
                "AppConfig",
                "Reminder2CalSync"
            ],
            path: "Sources/Reminder2Cal"
        ),
    ],

    // Swift language version
    swiftLanguageVersions: [.v5]
)
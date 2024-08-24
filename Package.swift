// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Reminder2Cal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Reminder2Cal", targets: ["Reminder2Cal"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AppConfig",
            dependencies: [],
            path: "Sources/AppConfig"
        ),
        .executableTarget(
            name: "Reminder2Cal",
            dependencies: ["AppConfig"],
            path: "Sources/Reminder2Cal"
        ),
    ]
)
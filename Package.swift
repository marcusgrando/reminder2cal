// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Reminder2Cal",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-format.git", exact: "602.0.0")
    ]
)

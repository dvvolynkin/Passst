// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Passst",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Passst", targets: ["Passst"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(
            url: "https://github.com/sindresorhus/KeyboardShortcuts.git",
            exact: "1.12.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "Passst",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Passst",
            exclude: [
                "Info.plist",
                "Passst.entitlements",
                "Resources"
            ]
        ),
        .testTarget(
            name: "PassstTests",
            dependencies: ["Passst"],
            path: "PassstTests"
        )
    ],
    swiftLanguageModes: [.v6]
)

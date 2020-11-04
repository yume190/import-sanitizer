// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImportSanitizer",
    products: [
        .executable(name: "importsanitizer", targets: ["ImportSanitizer"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/JohnSundell/Files",
            from: "4.1.1"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "0.3.1"
        )
    ],
    targets: [
        .target(
            name: "ImportSanitizer",
            dependencies: ["ImportSanitizerCore"]),
        .target(
            name: "ImportSanitizerCore",
            dependencies: ["Files",
                           .product(name: "ArgumentParser",
                                    package: "swift-argument-parser"),
            ]
        )
    ]
)

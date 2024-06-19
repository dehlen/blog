// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "blog.swift",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "main", targets: ["main"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.2"),
        .package(url: "https://github.com/apple/swift-cmark.git", .branch("main")),
        .package(url: "https://github.com/dehlen/Swim.git", .branch("main"))
    ],
    targets: [
        .executableTarget(
            name: "main",
            dependencies: [
                "blog.swift",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .target(
            name: "blog.swift",
            dependencies: [
                .product(name: "cmark", package: "swift-cmark"),
                .product(name: "HTML", package: "Swim")
            ]),
    ]
)

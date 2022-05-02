// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Omnibus",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Omnibus",
            targets: ["Omnibus"]),
        .library(
            name: "TypedChannels",
            targets: ["TypedChannels"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
//        .package(url: "https://github.com/orlandos-nl/Citadel.git", branch: "async-await"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TypedChannels",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
            ]),
        .target(
            name: "Omnibus",
            dependencies: [
                "TypedChannels",
                .product(name: "NIO", package: "swift-nio"),
//                .product(name: "Citadel", package: "Citadel"),
            ]),
        .testTarget(
            name: "OmnibusTests",
            dependencies: [
                "TypedChannels",
                "Omnibus",
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ]),
    ]
)

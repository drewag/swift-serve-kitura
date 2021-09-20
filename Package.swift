// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SwiftServeKitura",
    platforms: [
        .macOS(.v10_12),
    ],
    products: [
        .library(name: "SwiftServeKitura", targets: ["SwiftServeKitura"]),
    ],
    dependencies: [
        .package(url: "https://github.com/drewag/swift-serve.git", from: "19.0.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura.git", from: "2.5.0"),
    ],
    targets: [
        .target(name: "SwiftServeKitura", dependencies: ["SwiftServe", "Kitura"], path: "Sources"),
        .testTarget(name: "SwiftServeKituraTests", dependencies: ["SwiftServeKitura"]),
    ]
)

import PackageDescription

let package = Package(
    name: "SwiftServeKitura",
    dependencies: [
        .Package(url: "https://github.com/drewag/swift-serve.git", majorVersion: 9),

        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 2, minor: 0),
    ]
)

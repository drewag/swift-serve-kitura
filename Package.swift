import PackageDescription

let package = Package(
    name: "SwiftServeKitura",
    dependencies: [
        .Package(url: "https://github.com/drewag/swift-serve.git", majorVersion: 5),

        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1, minor: 2),
        .Package(url: "https://github.com/Zewo/File.git", majorVersion: 0, minor: 14),
    ]
)

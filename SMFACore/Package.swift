// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SMFACore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "SMFACore", targets: ["SMFACore"])
    ],
    targets: [
        .target(name: "SMFACore"),
        .testTarget(name: "SMFACoreTests", dependencies: ["SMFACore"])
    ]
)

// swift-tools-version: 5.9
import PackageDescription

// The native Superwall adapter: the PingFrontSuperwall product of https://github.com/pingfront/pingfront-ios-superwall.
// Each vendor's adapter is its own package, so Swift Package Manager fetches Superwall and no other vendor.
let adapter: Package.Dependency = .package(url: "https://github.com/pingfront/pingfront-ios-superwall", from: "1.0.0")
let adapterPackage = "pingfront-ios-superwall"

let package = Package(
    name: "pingfront_superwall",
    platforms: [.iOS("17.0")],
    products: [
        .library(name: "pingfront-superwall", targets: ["pingfront_superwall"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        adapter,
    ],
    targets: [
        .target(
            name: "pingfront_superwall",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "PingFrontSuperwall", package: adapterPackage),
            ]
        )
    ]
)

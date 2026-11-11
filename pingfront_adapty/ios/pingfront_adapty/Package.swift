// swift-tools-version: 5.9
import PackageDescription

// The native Adapty adapter: the PingFrontAdapty product of https://github.com/pingfront/pingfront-ios-adapty.
// Each vendor's adapter is its own package, so Swift Package Manager fetches Adapty and no other vendor.
let adapter: Package.Dependency = .package(url: "https://github.com/pingfront/pingfront-ios-adapty", from: "1.0.0")
let adapterPackage = "pingfront-ios-adapty"

let package = Package(
    name: "pingfront_adapty",
    platforms: [.iOS("17.0")],
    products: [
        .library(name: "pingfront-adapty", targets: ["pingfront_adapty"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        adapter,
    ],
    targets: [
        .target(
            name: "pingfront_adapty",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "PingFrontAdapty", package: adapterPackage),
            ]
        )
    ]
)

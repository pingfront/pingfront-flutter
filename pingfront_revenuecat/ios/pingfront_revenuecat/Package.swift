// swift-tools-version: 5.9
import PackageDescription

// The native RevenueCat adapter: the PingFrontRevenueCat product of https://github.com/pingfront/pingfront-ios-revenuecat.
// Each vendor's adapter is its own package, so Swift Package Manager fetches RevenueCat and no other vendor.
let adapter: Package.Dependency = .package(url: "https://github.com/pingfront/pingfront-ios-revenuecat", from: "1.0.0")
let adapterPackage = "pingfront-ios-revenuecat"

let package = Package(
    name: "pingfront_revenuecat",
    platforms: [.iOS("17.0")],
    products: [
        .library(name: "pingfront-revenuecat", targets: ["pingfront_revenuecat"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        adapter,
    ],
    targets: [
        .target(
            name: "pingfront_revenuecat",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "PingFrontRevenueCat", package: adapterPackage),
            ]
        )
    ]
)

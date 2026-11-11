// swift-tools-version: 5.9
import PackageDescription

// The native pingfront SDK, the PingFront product of https://github.com/pingfront/pingfront-ios.
let nativeSDK: Package.Dependency = .package(url: "https://github.com/pingfront/pingfront-ios", from: "1.0.0")
let nativeSDKPackage = "pingfront-ios"

let package = Package(
    name: "pingfront_flutter",
    platforms: [.iOS("17.0")],
    products: [
        .library(name: "pingfront-flutter", targets: ["pingfront_flutter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        nativeSDK,
    ],
    targets: [
        .target(
            name: "pingfront_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "PingFront", package: nativeSDKPackage),
            ],
            resources: [.process("PrivacyInfo.xcprivacy")]
        )
    ]
)

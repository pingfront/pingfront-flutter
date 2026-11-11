/// The product name and every identifier derived from it on the iOS side, in one place.
/// Dart keeps its copy in `lib/src/brand.dart`, Kotlin in `Names.kt`.
enum Names {
    /// The platform view type of the embedded chat (`PingFrontChatView` in Dart).
    static let chatViewType = "dev.pingfront/chat_view"

    /// The Objective-C class each vendor add-on package registers, by adapter id. The class answers
    /// `+moduleWithOptions:` with the native `PingFrontModule` (see `Adapters.swift`).
    static let adapterClasses: [String: String] = [
        "revenuecat": "PingFrontFlutterRevenueCatAdapter",
        "superwall": "PingFrontFlutterSuperwallAdapter",
        "adapty": "PingFrontFlutterAdaptyAdapter",
    ]

    /// The add-on package for each adapter id, for the error message when it is missing.
    static let adapterPackages: [String: String] = [
        "revenuecat": "pingfront_revenuecat",
        "superwall": "pingfront_superwall",
        "adapty": "pingfront_adapty",
    ]
}

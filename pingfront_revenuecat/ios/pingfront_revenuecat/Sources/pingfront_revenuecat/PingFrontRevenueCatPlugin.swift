import Flutter
import Foundation
import PingFrontCore
import PingFrontRevenueCat

/// Registers nothing: the plugin exists so Flutter links the native adapter. `pingfront_flutter` asks
/// ``PingFrontFlutterRevenueCatAdapter`` for the module when Dart configures with `PingFrontRevenueCat.module()`.
public final class PingFrontRevenueCatPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: any FlutterPluginRegistrar) {}
}

/// Builds the native adapter from the options Dart sent. `pingfront_flutter` finds the class by its Objective-C
/// name and calls `+moduleWithOptions:`, so the two plugins share no Swift types beyond the SDK's.
@objc(PingFrontFlutterRevenueCatAdapter)
public final class PingFrontFlutterRevenueCatAdapter: NSObject {
    @objc(moduleWithOptions:)
    public static func module(options: NSDictionary) -> Any {
        PingFrontModule.revenueCat(
            RevenueCatOptions(
                offerings: options["offerings"] as? [String],
                presentsPaywalls: options["presentsPaywalls"] as? Bool ?? true))
    }
}

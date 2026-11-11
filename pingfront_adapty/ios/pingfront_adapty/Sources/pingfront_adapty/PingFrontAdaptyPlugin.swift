import Flutter
import Foundation
import PingFrontCore
import PingFrontAdapty

/// Registers nothing: the plugin exists so Flutter links the native adapter. `pingfront_flutter` asks
/// ``PingFrontFlutterAdaptyAdapter`` for the module when Dart configures with `PingFrontAdapty.module()`.
public final class PingFrontAdaptyPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: any FlutterPluginRegistrar) {}
}

/// Builds the native adapter from the options Dart sent. `pingfront_flutter` finds the class by its Objective-C
/// name and calls `+moduleWithOptions:`, so the two plugins share no Swift types beyond the SDK's.
@objc(PingFrontFlutterAdaptyAdapter)
public final class PingFrontFlutterAdaptyAdapter: NSObject {
    @objc(moduleWithOptions:)
    public static func module(options: NSDictionary) -> Any {
        let identity: AdaptyIdentity =
            switch options["identity"] as? String {
            case "storeAccountToken": .storeAccountToken
            case "customerUserId": .customerUserId { currentUserId() }
            default: .appManaged
            }
        return PingFrontModule.adapty(
            AdaptyOptions(
                placements: options["placements"] as? [String] ?? [], identity: identity,
                observerMode: options["observerMode"] as? Bool ?? false, presentsPaywalls: options["presentsPaywalls"] as? Bool ?? true,
                reportsEntitlement: options["reportsEntitlement"] as? Bool ?? true))
    }

    /// The id from the latest `PingFront.identify`, which the pingfront_flutter plugin keeps in memory.
    private static func currentUserId() -> String? {
        guard let identity = NSClassFromString("PingFrontFlutterIdentity") as AnyObject as? NSObjectProtocol else { return nil }
        return identity.perform(NSSelectorFromString("currentUserId"))?.takeUnretainedValue() as? String
    }
}

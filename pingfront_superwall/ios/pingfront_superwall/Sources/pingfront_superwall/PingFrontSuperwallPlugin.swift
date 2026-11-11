import Flutter
import Foundation
import PingFrontCore
import PingFrontSuperwall

/// Registers nothing: the plugin exists so Flutter links the native adapter. `pingfront_flutter` asks
/// ``PingFrontFlutterSuperwallAdapter`` for the module when Dart configures with `PingFrontSuperwall.module()`.
public final class PingFrontSuperwallPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: any FlutterPluginRegistrar) {}
}

/// Builds the native adapter from the options Dart sent. `pingfront_flutter` finds the class by its Objective-C
/// name and calls `+moduleWithOptions:`, so the two plugins share no Swift types beyond the SDK's.
@objc(PingFrontFlutterSuperwallAdapter)
public final class PingFrontFlutterSuperwallAdapter: NSObject {
    @objc(moduleWithOptions:)
    public static func module(options: NSDictionary) -> Any {
        let placements = (options["placements"] as? [[String: Any]] ?? []).compactMap { p -> SuperwallPlacement? in
            guard let name = p["placement"] as? String, let title = p["title"] as? String else { return nil }
            let products = (p["products"] as? [[String: Any]] ?? []).compactMap { product -> OfferSlot.Product? in
                guard let id = product["id"] as? String, let price = product["price"] as? String else { return nil }
                return OfferSlot.Product(id: id, price: price, period: product["period"] as? String, trial: product["trial"] as? String)
            }
            return SuperwallPlacement(
                name, title: title, kind: OfferSlot.Kind(rawValue: p["kind"] as? String ?? "") ?? .standard, products: products,
                params: p["params"] as? [String: String] ?? [:])
        }
        let identity: SuperwallIdentity = options["identity"] as? String == "storeAccountToken" ? .storeAccountToken : .appManaged
        return PingFrontModule.superwall(
            placements: placements, identity: identity, reportsEntitlement: options["reportsEntitlement"] as? Bool ?? true)
    }
}

import Foundation
import PingFront
import os

/// Vendor adapters come from add-on packages (`pingfront_revenuecat`, `pingfront_superwall`,
/// `pingfront_adapty`), so an app links only the vendor it uses and this plugin has no vendor
/// dependency. Each add-on registers an Objective-C class (`Names.adapterClasses`) whose class method
/// `+moduleWithOptions:` builds the native adapter (`PingFrontModule`) from the options Dart sent.
enum Adapters {
    private static let log = Logger(subsystem: "dev.pingfront.flutter", category: "adapters")

    /// The adapter's module, or `nil` (logged) when the add-on is not in the app.
    static func module(id: String, options: [String: Any?]) -> PingFrontModule? {
        guard let className = Names.adapterClasses[id] else {
            log.error("Unknown module \(id, privacy: .public); it was skipped.")
            return nil
        }
        let selector = NSSelectorFromString("moduleWithOptions:")
        guard let factory = NSClassFromString(className) as AnyObject as? NSObjectProtocol, factory.responds(to: selector) else {
            let package = Names.adapterPackages[id] ?? id
            log.error("The \(id, privacy: .public) adapter needs the \(package, privacy: .public) package in your pubspec; it was skipped.")
            return nil
        }
        let arguments = NSDictionary(dictionary: options.compactMapValues { $0 })
        guard let result = factory.perform(selector, with: arguments)?.takeUnretainedValue(), let module = result as? PingFrontModule else {
            log.error("The \(id, privacy: .public) add-on returned no module; it was skipped.")
            return nil
        }
        return module
    }
}

/// The user id from the latest `identify(userId:)` or `identifyWithToken` (the token's `sub`), for add-ons whose
/// vendor identifies the person with the app's own id (Adapty's `customerUserId`). In memory only; cleared by logout
/// and by an erase that succeeds.
@objc(PingFrontFlutterIdentity)
public final class PingFrontFlutterIdentity: NSObject {
    /// Read by add-ons through `NSClassFromString("PingFrontFlutterIdentity")`.
    @objc public internal(set) static var currentUserId: String?
}

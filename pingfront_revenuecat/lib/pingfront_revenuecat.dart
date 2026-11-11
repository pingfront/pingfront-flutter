/// RevenueCat for pingfront: offerings become offer slots, an offer card opens the offering's RevenueCat
/// paywall, and the customer's entitlements become the person's entitlement. The native adapters do the
/// work (`PingFrontRevenueCat` on iOS, `sh.pingfront:pingfront-revenuecat` on Android); this package
/// brings them, and RevenueCat, only into apps that add it.
///
/// ```dart
/// await Purchases.configure(PurchasesConfiguration('appl_…'));   // RevenueCat first (or right after)
/// await PingFront.configure(
///   'pk_live_…',
///   options: PingFrontOptions(modules: [PingFrontRevenueCat.module()]),
/// );
/// ```
///
/// Leave `PingFront.onOffer` unset: when it is set, it takes the offer cards instead of the adapter.
library;

import 'package:pingfront_flutter/pingfront_flutter.dart';

/// The RevenueCat adapter.
abstract final class PingFrontRevenueCat {
  /// The adapter id the native factories answer to.
  static const String id = 'revenuecat';

  /// The adapter, for [PingFrontOptions.modules].
  ///
  /// iOS reads both options: [offerings] are the offering identifiers to report, in order (`null`: every
  /// offering, the current one first), and [presentsPaywalls] presents RevenueCatUI paywalls for offerings
  /// that have one. Android reports every offering and always presents RevenueCat paywalls.
  static PingFrontModule module({
    List<String>? offerings,
    bool presentsPaywalls = true,
  }) => AdapterModule(id, {
    'offerings': offerings,
    'presentsPaywalls': presentsPaywalls,
  });
}

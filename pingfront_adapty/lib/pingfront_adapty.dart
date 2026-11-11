/// Adapty for pingfront: placements become offer slots, an offer card opens the placement's Adapty
/// paywall, and the profile's access levels become the person's entitlement. The native adapters do the
/// work (`PingFrontAdapty` on iOS, `sh.pingfront:pingfront-adapty` on Android); this package brings
/// them, and Adapty, only into apps that add it.
///
/// ```dart
/// await PingFront.configure(
///   'pk_live_…',
///   options: PingFrontOptions(modules: [
///     PingFrontAdapty.module(placements: ['winback', 'settings_paywall']),
///   ]),
/// );
/// ```
///
/// Activate Adapty (and AdaptyUI) first, or right after. Leave `PingFront.onOffer` unset: when it is set,
/// it takes the offer cards instead of the adapter.
library;

import 'package:pingfront_flutter/pingfront_flutter.dart';

/// Who identifies the person to Adapty. iOS only; on Android your app identifies Adapty itself.
enum AdaptyIdentity {
  /// Your app calls Adapty's `identify` and passes `PingFront.storeAccountToken()` as the app account
  /// token (the default).
  appManaged,

  /// The adapter calls Adapty's `identify` with the id from the latest `PingFront.identify` (or the
  /// `sub` of the latest `PingFront.identifyWithToken`) and the store account token, whenever the token
  /// changes.
  customerUserId,

  /// The adapter identifies Adapty with the store account token, for apps without their own user ids.
  storeAccountToken,
}

/// The Adapty adapter.
abstract final class PingFrontAdapty {
  /// The adapter id the native factories answer to.
  static const String id = 'adapty';

  /// The adapter, for [PingFrontOptions.modules]. [placements] are the placement ids the team can offer.
  /// The other options are iOS only: [observerMode] when your code buys (the adapter then never buys),
  /// [presentsPaywalls] for Paywall Builder paywalls, and [reportsEntitlement] to report access levels.
  static PingFrontModule module({
    required List<String> placements,
    AdaptyIdentity identity = AdaptyIdentity.appManaged,
    bool observerMode = false,
    bool presentsPaywalls = true,
    bool reportsEntitlement = true,
  }) => AdapterModule(id, {
    'placements': placements,
    'identity': identity.name,
    'observerMode': observerMode,
    'presentsPaywalls': presentsPaywalls,
    'reportsEntitlement': reportsEntitlement,
  });
}

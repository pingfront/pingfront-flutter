/// Superwall for pingfront: placements become offer slots, an offer card registers the placement (so
/// Superwall's audiences and holdouts decide), and the subscription status becomes the person's
/// entitlement. The native adapters do the work (`PingFrontSuperwall` on iOS,
/// `sh.pingfront:pingfront-superwall` on Android); this package brings them, and Superwall, only into
/// apps that add it.
///
/// ```dart
/// await PingFront.configure(
///   'pk_live_…',
///   options: PingFrontOptions(modules: [
///     PingFrontSuperwall.module(placements: [
///       SuperwallPlacement('winback_offer', title: 'Come back for 50% off', kind: OfferKind.winback),
///     ]),
///   ]),
/// );
/// ```
///
/// Configure Superwall itself first (or right after). Leave `PingFront.onOffer` unset: when it is set,
/// it takes the offer cards instead of the adapter.
library;

import 'package:flutter/foundation.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';

/// A Superwall placement the team can send as an offer card.
@immutable
class SuperwallPlacement {
  /// Creates a placement. [placement] is the name in the Superwall dashboard (also the slot id); [title]
  /// is what the team sees (at most 60 characters).
  const SuperwallPlacement(
    this.placement, {
    required this.title,
    this.kind = OfferKind.standard,
    this.products = const [],
    this.params = const {},
  });

  /// The placement name.
  final String placement;

  /// The title the team sees in the dashboard.
  final String title;

  /// The kind of offer.
  final OfferKind kind;

  /// iOS: the products the paywall sells, shown on the slot; the slot is unavailable once the person owns
  /// all of them. Android ignores it.
  final List<OfferProduct> products;

  /// iOS: parameters passed to `register(placement:params:)`, for audience filters. Android ignores them.
  final Map<String, String> params;
}

/// How Superwall knows who the person is, so its webhooks match them. iOS only; on Android your app
/// identifies Superwall itself.
enum SuperwallIdentity {
  /// Your app calls Superwall's `identify` with the id it passes to `PingFront.identify` (the default).
  appManaged,

  /// The adapter identifies Superwall with the store account token, for apps without their own user ids.
  storeAccountToken,
}

/// The Superwall adapter.
abstract final class PingFrontSuperwall {
  /// The adapter id the native factories answer to.
  static const String id = 'superwall';

  /// The adapter, for [PingFrontOptions.modules]. [identity] and [reportsEntitlement] are iOS only
  /// (turn [reportsEntitlement] off when RevenueCat or StoreKit already reports the entitlement).
  static PingFrontModule module({
    required List<SuperwallPlacement> placements,
    SuperwallIdentity identity = SuperwallIdentity.appManaged,
    bool reportsEntitlement = true,
  }) => AdapterModule(id, {
    'placements': [
      for (final p in placements)
        {
          'placement': p.placement,
          'title': p.title,
          'kind': p.kind.name,
          'products': [
            for (final product in p.products)
              {
                'id': product.id,
                'price': product.price,
                'period': product.period,
                'trial': product.trial,
              },
          ],
          'params': p.params,
        },
    ],
    'identity': identity.name,
    'reportsEntitlement': reportsEntitlement,
  });
}

# pingfront_superwall

The Superwall adapter for [pingfront_flutter](https://pub.dev/packages/pingfront_flutter). Superwall placements become offer slots your team can send, an offer card registers the placement (so Superwall's audiences and holdouts decide what shows), and the subscription status becomes the person's entitlement.

The native pingfront adapters do the work: `PingFrontSuperwall` from
[pingfront-ios-superwall](https://github.com/pingfront/pingfront-ios-superwall) on iOS and `sh.pingfront:pingfront-superwall` from Maven
Central on Android. They bring Superwall's native SDK, so only apps that add this package link Superwall.

## Install

```yaml
dependencies:
  pingfront_flutter: ^1.0.0
  pingfront_superwall: ^1.0.0
```

The requirements are those of `pingfront_flutter`: Flutter 3.47 or later, iOS 17 with Flutter's Swift Package Manager
support on, and Android 8.0 (API 26) with `compileSdk` 36 or later.

## Use

Configure Superwall yourself, before `PingFront.configure` or right after it. Then pass the module:

```dart
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_superwall/pingfront_superwall.dart';

await PingFront.configure(
  'pk_live_…',
  options: PingFrontOptions(modules: [
    PingFrontSuperwall.module(placements: const [
      SuperwallPlacement('winback_offer', title: 'Come back for 50% off', kind: OfferKind.winback),
    ]),
  ]),
);
```

Leave `PingFront.onOffer` unset: when it is set, it takes the offer cards instead of the adapter. If the native
adapter is missing from a build, the module is skipped with a log line, never a crash.

## Options

- `placements`: the placements the team can send. `title` is what the team sees (at most 60 characters). On iOS a placement can also list the `products` its paywall sells and the `params` passed to `register`.
- `identity` (iOS): who identifies the person to Superwall. `SuperwallIdentity.appManaged` (the default) means your app calls Superwall's `identify` with the id it passes to `PingFront.identify`.
- `reportsEntitlement` (iOS): turn it off when RevenueCat or StoreKit already reports the entitlement.

Options marked iOS are ignored on Android, where the adapter takes the placements only.

## Learn more

- [Flutter quickstart](https://pingfront.sh/docs/flutter)
- [What the adapters do](https://pingfront.sh/docs/modules#revenuecat-superwall-and-adapty)
- [Offers](https://pingfront.sh/docs/offers)

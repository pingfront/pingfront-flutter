# pingfront_revenuecat

The RevenueCat adapter for [pingfront_flutter](https://pub.dev/packages/pingfront_flutter). RevenueCat offerings become offer slots your team can send, an offer card opens the offering's RevenueCat paywall, and the customer's entitlements become the person's entitlement.

The native pingfront adapters do the work: `PingFrontRevenueCat` from
[pingfront-ios-revenuecat](https://github.com/pingfront/pingfront-ios-revenuecat) on iOS and `sh.pingfront:pingfront-revenuecat` from Maven
Central on Android. They bring RevenueCat's native SDK, so only apps that add this package link RevenueCat.

## Install

```yaml
dependencies:
  pingfront_flutter: ^1.0.0
  pingfront_revenuecat: ^1.0.0
```

The requirements are those of `pingfront_flutter`: Flutter 3.47 or later, iOS 17 with Flutter's Swift Package Manager
support on, and Android 8.0 (API 26) with `compileSdk` 36 or later.

## Use

Configure RevenueCat yourself (for example with `Purchases.configure` from `purchases_flutter`), before `PingFront.configure` or right after it. Then pass the module:

```dart
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_revenuecat/pingfront_revenuecat.dart';

await PingFront.configure(
  'pk_live_…',
  options: PingFrontOptions(modules: [PingFrontRevenueCat.module()]),
);
```

Leave `PingFront.onOffer` unset: when it is set, it takes the offer cards instead of the adapter. If the native
adapter is missing from a build, the module is skipped with a log line, never a crash.

## Options

- `offerings` (iOS): the offering identifiers to report, in order. `null` reports every offering, the current one first. Android reports every offering.
- `presentsPaywalls` (iOS): present RevenueCatUI paywalls for offerings that have one. Android always presents RevenueCat paywalls.

Options marked iOS are ignored on Android, where the adapter takes the placements only.

## Learn more

- [Flutter quickstart](https://pingfront.sh/docs/flutter)
- [What the adapters do](https://pingfront.sh/docs/modules#revenuecat-superwall-and-adapty)
- [Offers](https://pingfront.sh/docs/offers)

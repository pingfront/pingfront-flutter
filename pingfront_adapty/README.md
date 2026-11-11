# pingfront_adapty

The Adapty adapter for [pingfront_flutter](https://pub.dev/packages/pingfront_flutter). Adapty placements become offer slots your team can send, an offer card opens the placement's Adapty paywall, and the profile's access levels become the person's entitlement.

The native pingfront adapters do the work: `PingFrontAdapty` from
[pingfront-ios-adapty](https://github.com/pingfront/pingfront-ios-adapty) on iOS and `sh.pingfront:pingfront-adapty` from Maven
Central on Android. They bring Adapty's native SDK, so only apps that add this package link Adapty.

## Install

```yaml
dependencies:
  pingfront_flutter: ^1.0.0
  pingfront_adapty: ^1.0.0
```

The requirements are those of `pingfront_flutter`: Flutter 3.47 or later, iOS 17 with Flutter's Swift Package Manager
support on, and Android 8.0 (API 26) with `compileSdk` 36 or later.

## Use

Activate Adapty (and AdaptyUI) yourself, before `PingFront.configure` or right after it. Then pass the module:

```dart
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_adapty/pingfront_adapty.dart';

await PingFront.configure(
  'pk_live_…',
  options: PingFrontOptions(modules: [
    PingFrontAdapty.module(placements: ['winback', 'settings_paywall']),
  ]),
);
```

Leave `PingFront.onOffer` unset: when it is set, it takes the offer cards instead of the adapter. If the native
adapter is missing from a build, the module is skipped with a log line, never a crash.

## Options

- `placements`: the placement ids the team can send.
- `identity` (iOS): who identifies the person to Adapty. `AdaptyIdentity.appManaged` (the default) means your app calls Adapty's `identify` and passes `PingFront.storeAccountToken()` as the app account token.
- `observerMode` (iOS): your code makes the purchases; the adapter never buys.
- `presentsPaywalls` (iOS): present Paywall Builder paywalls.
- `reportsEntitlement` (iOS): report the access levels as the person's entitlement.

Options marked iOS are ignored on Android, where the adapter takes the placements only.

## Learn more

- [Flutter quickstart](https://pingfront.sh/docs/flutter)
- [What the adapters do](https://pingfront.sh/docs/modules#revenuecat-superwall-and-adapty)
- [Offers](https://pingfront.sh/docs/offers)
